Fs          = require 'fs'
Dns         = require 'dns'
Url         = require 'url'
Http        = require 'http'
Crypto      = require 'crypto'
QueryString = require 'querystring'

port            = parseInt process.env.PORT        || 8081
version         = "1.3.0"
shared_key      = process.env.CAMO_KEY             || '0x24FEEDFACEDEADBEEFCAFE'
max_redirects   = process.env.CAMO_MAX_REDIRECTS   || 4
camo_hostname   = process.env.CAMO_HOSTNAME        || "unknown"
socket_timeout  = process.env.CAMO_SOCKET_TIMEOUT  || 10
logging_enabled = process.env.CAMO_LOGGING_ENABLED || "disabled"
content_length_limit = parseInt(process.env.CAMO_LENGTH_LIMIT || 5242880, 10)

debug_log = (msg) ->
  if logging_enabled == "debug"
    console.log("--------------------------------------------")
    console.log(msg)
    console.log("--------------------------------------------")

error_log = (msg) ->
  unless logging_enabled == "disabled"
    console.error("[#{new Date().toISOString()}] #{msg}")

RESTRICTED_IPS = /^((10\.)|(127\.)|(169\.254)|(192\.168)|(172\.((1[6-9])|(2[0-9])|(3[0-1]))))/

total_connections   = 0
current_connections = 0
started_at          = new Date

four_oh_four = (resp, msg, url) ->
  error_log "#{msg}: #{url?.format() or 'unknown'}"
  resp.writeHead 404
  finish resp, "Not Found"

finish = (resp, str) ->
  current_connections -= 1
  current_connections  = 0 if current_connections < 1
  resp.connection && resp.end str

# A Transform Stream that limits the piped data to the specified length
Stream = require('stream')
class LimitStream extends Stream.Transform
  constructor: (length) ->
    super()
    @remaining = length

  _transform: (chunk, encoding, cb) ->
    if @remaining > 0
      if @remaining < chunk.length
        chunk = chunk.slice(0, @remaining)
      @push(chunk)
      @remaining -= chunk.length
      if @remaining <= 0
        @emit('length_limited')
        @end()
    cb()

  write: (chunk, encoding, cb) ->
    if @remaining > 0
      super
    else
      false

process_url = (url, transferred_headers, resp, remaining_redirects) ->
  if !url.host?
    return four_oh_four(resp, "Invalid host", url)

  if url.protocol == 'https:'
    error_log("Redirecting https URL to origin: #{url.format()}")
    resp.writeHead 301, {'Location': url.format()}
    finish resp
    return
  else if url.protocol != 'http:'
    four_oh_four(resp, "Unknown protocol", url)
    return

  Dns.lookup url.hostname, (err, address, family) ->
    if err
      return four_oh_four(resp, "No host found: #{err}", url)

    if address.match(RESTRICTED_IPS)
      return four_oh_four(resp, "Hitting excluded IP", url)

    fetch_url address, url, transferred_headers, resp, remaining_redirects

  fetch_url = (ip_address, url, transferred_headers, resp, remaining_redirects) ->
    queryPath = url.pathname
    if url.query?
      queryPath += "?#{url.query}"

    transferred_headers.host = url.host
    debug_log transferred_headers

    requestOptions =
      hostname: url.hostname
      port: url.port ? 80
      path: queryPath
      headers: transferred_headers

    srcReq = Http.get requestOptions, (srcResp) ->
      is_finished = true

      debug_log srcResp.headers

      content_length = srcResp.headers['content-length']

      if content_length > content_length_limit
        srcResp.destroy()
        four_oh_four(resp, "Content-Length exceeded", url)
      else
        newHeaders =
          'content-type'           : srcResp.headers['content-type']
          'cache-control'          : srcResp.headers['cache-control'] || 'public, max-age=31536000'
          'Camo-Host'              : camo_hostname
          'X-Content-Type-Options' : 'nosniff'

        # Handle chunked responses properly
        if content_length?
          newHeaders['content-length'] = content_length
        if srcResp.headers['transfer-encoding']
          newHeaders['transfer-encoding'] = srcResp.headers['transfer-encoding']
        if srcResp.headers['content-encoding']
          newHeaders['content-encoding'] = srcResp.headers['content-encoding']

        srcResp.on 'end', ->
          if is_finished
            finish resp
        srcResp.on 'error', ->
          if is_finished
            finish resp

        switch srcResp.statusCode
          when 200
            if newHeaders['content-type'] && newHeaders['content-type'].slice(0, 5) != 'image'
              srcResp.destroy()
              four_oh_four(resp, "Non-Image content-type returned", url)
              return

            debug_log newHeaders

            resp.writeHead srcResp.statusCode, newHeaders

            limit = new LimitStream(content_length_limit)
            srcResp.pipe(limit)
            limit.pipe(resp)

            limit.on 'length_limited', ->
              srcResp.destroy()
              error_log("Killed connection at content_length_limit: #{url.format()}")

          when 301, 302, 303, 307
            srcResp.destroy()
            if remaining_redirects <= 0
              four_oh_four(resp, "Exceeded max depth", url)
            else if !srcResp.headers['location']
              four_oh_four(resp, "Redirect with no location", url)
            else
              is_finished = false
              newUrl = Url.parse srcResp.headers['location']
              unless newUrl.host? and newUrl.hostname?
                newUrl.host = newUrl.hostname = url.hostname
                newUrl.protocol = url.protocol

              debug_log "Redirected to #{newUrl.format()}"
              process_url newUrl, transferred_headers, resp, remaining_redirects - 1
          when 304
            srcResp.destroy()
            resp.writeHead srcResp.statusCode, newHeaders
          else
            srcResp.destroy()
            four_oh_four(resp, "Origin responded with #{srcResp.statusCode}", url)

    srcReq.setTimeout (socket_timeout * 1000), ->
      srcReq.abort()
      four_oh_four resp, "Socket timeout", url

    srcReq.on 'error', (error) ->
      four_oh_four(resp, "Client Request error #{error.stack}", url)

    resp.on 'close', ->
      error_log("Request aborted")
      srcReq.abort()

    resp.on 'error', (e) ->
      error_log("Request error: #{e}")
      srcReq.abort()

# decode a string of two char hex digits
hexdec = (str) ->
  if str and str.length > 0 and str.length % 2 == 0 and not str.match(/[^0-9a-f]/)
    buf = new Buffer(str.length / 2)
    for i in [0...str.length] by 2
      buf[i/2] = parseInt(str[i..i+1], 16)
    buf.toString()

server = Http.createServer (req, resp) ->
  if req.method != 'GET' || req.url == '/'
    resp.writeHead 200
    resp.end 'hwhat'
  else if req.url == '/favicon.ico'
    resp.writeHead 200
    resp.end 'ok'
  else if req.url == '/status'
    resp.writeHead 200
    resp.end "ok #{current_connections}/#{total_connections} since #{started_at.toString()}"
  else
    total_connections   += 1
    current_connections += 1
    url = Url.parse req.url
    user_agent = process.env.CAMO_HEADER_VIA or= "Camo Asset Proxy #{version}"

    transferred_headers =
      'Via'                    : user_agent
      'User-Agent'             : user_agent
      'Accept'                 : req.headers.accept ? 'image/*'
      'Accept-Encoding'        : req.headers['accept-encoding']
      'x-content-type-options' : 'nosniff'

    delete(req.headers.cookie)

    [query_digest, encoded_url] = url.pathname.replace(/^\//, '').split("/", 2)
    if encoded_url = hexdec(encoded_url)
      url_type = 'path'
      dest_url = encoded_url
    else
      url_type = 'query'
      dest_url = QueryString.parse(url.query).url

    debug_log({
      type:     url_type
      url:      req.url
      headers:  req.headers
      dest:     dest_url
      digest:   query_digest
    })

    if req.headers['via'] && req.headers['via'].indexOf(user_agent) != -1
      return four_oh_four(resp, "Requesting from self")

    if url.pathname? && dest_url
      hmac = Crypto.createHmac("sha1", shared_key)
      hmac.update(dest_url, 'utf8')

      hmac_digest = hmac.digest('hex')

      if hmac_digest == query_digest
        url = Url.parse dest_url

        process_url url, transferred_headers, resp, max_redirects
      else
        four_oh_four(resp, "checksum mismatch #{hmac_digest}:#{query_digest}")
    else
      four_oh_four(resp, "No pathname provided on the server")

console.log "SSL-Proxy running on #{port} with pid:#{process.pid}."
console.log "Using the secret key #{shared_key}"

server.listen port
