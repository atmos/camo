Fs          = require 'fs'
Url         = require 'url'
Http        = require 'http'
Crypto      = require 'crypto'
QueryString = require 'querystring'

port            = parseInt process.env.PORT        || 8081
version         = "1.0.4"
excluded        = process.env.CAMO_HOST_EXCLUSIONS || '*.example.org'
shared_key      = process.env.CAMO_KEY             || '0x24FEEDFACEDEADBEEFCAFE'
max_redirects   = process.env.CAMO_MAX_REDIRECTS   || 4
camo_hostname   = process.env.CAMO_HOSTNAME        || "unknown"
logging_enabled = process.env.CAMO_LOGGING_ENABLED || "disabled"

log = (msg) ->
  unless logging_enabled == "disabled"
    console.log("--------------------------------------------")
    console.log(msg)
    console.log("--------------------------------------------")

EXCLUDED_HOSTS = new RegExp(excluded.replace(".", "\\.").replace("*", "\\.*"))
RESTRICTED_IPS = /^((10\.)|(127\.)|(169\.254)|(192\.168)|(172\.((1[6-9])|(2[0-9])|(3[0-1]))))/

total_connections   = 0
current_connections = 0
started_at          = new Date

four_oh_four = (resp, msg) ->
  log msg
  resp.writeHead 404
  finish resp, "Not Found"

finish = (resp, str) ->
  current_connections -= 1
  current_connections  = 0 if current_connections < 1
  resp.connection && resp.end str

process_url = (url, transferred_headers, resp, remaining_redirects) ->
  if url.host? && !url.host.match(RESTRICTED_IPS)
    if url.host.match(EXCLUDED_HOSTS)
      return four_oh_four(resp, "Hitting excluded hostnames")

    src = Http.createClient url.port || 80, url.hostname

    src.on 'error', (error) ->
      four_oh_four(resp, "Client Request error #{error.stack}")

    query_path = url.pathname
    if url.query?
      query_path += "?#{url.query}"

    transferred_headers.host = url.host

    log transferred_headers

    srcReq = src.request 'GET', query_path, transferred_headers

    srcReq.on 'response', (srcResp) ->
      is_finished = true

      log srcResp.headers

      content_length = srcResp.headers['content-length']

      if content_length > 5242880
        four_oh_four(resp, "Content-Length exceeded")
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
              four_oh_four(resp, "Non-Image content-type returned")

            log newHeaders

            resp.writeHead srcResp.statusCode, newHeaders
            srcResp.on 'data', (chunk) ->
              resp.write chunk
          when 301, 302, 303, 307
            if remaining_redirects <= 0
              four_oh_four(resp, "Exceeded max depth")
            else
              is_finished = false
              newUrl = Url.parse srcResp.headers['location']
              unless newUrl.host? and newUrl.hostname?
                newUrl.host = newUrl.hostname = url.hostname
                newUrl.protocol = url.protocol

              console.log newUrl
              process_url newUrl, transferred_headers, resp, remaining_redirects - 1
          when 304
            resp.writeHead srcResp.statusCode, newHeaders
          else
            four_oh_four(resp, "Responded with " + srcResp.statusCode + ":" + srcResp.headers)
    srcReq.on 'error', ->
      finish resp

    srcReq.end()
  else
    four_oh_four(resp, "No host found " + url.host)

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
      'Accept'                 : req.headers.accept
      'Accept-Encoding'        : req.headers['accept-encoding']
      'x-forwarded-for'        : req.headers['x-forwarded-for']
      'x-content-type-options' : 'nosniff'

    delete(req.headers.cookie)

    [query_digest, encoded_url] = url.pathname.replace(/^\//, '').split("/", 2)
    if encoded_url = hexdec(encoded_url)
      url_type = 'path'
      dest_url = encoded_url
    else
      url_type = 'query'
      dest_url = QueryString.parse(url.query).url
    
    log({
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
      hmac.update(dest_url)

      hmac_digest = hmac.digest('hex')

      if hmac_digest == query_digest
        dest_url = encodeURI(decodeURI(dest_url))
        url = Url.parse dest_url

        process_url url, transferred_headers, resp, max_redirects
      else
        four_oh_four(resp, "checksum mismatch #{hmac_digest}:#{query_digest}")
    else
      four_oh_four(resp, "No pathname provided on the server")

console.log "SSL-Proxy running on #{port} with pid:#{process.pid}."
console.log "Using the secret key #{shared_key}"

Fs.open "tmp/camo.pid", "w", 0o600, (err, fd) ->
  Fs.writeSync fd, process.pid

server.listen port
