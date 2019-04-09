Fs          = require 'fs'
Path        = require 'path'
Url         = require 'url'
Http        = require 'http'
Https       = require 'https'
Crypto      = require 'crypto'
QueryString = require 'querystring'

port            = parseInt process.env.PORT        || 8081, 10
version         = require(Path.resolve(__dirname, "package.json")).version
shared_key      = process.env.CAMO_KEY             || '0x24FEEDFACEDEADBEEFCAFE'
max_redirects   = process.env.CAMO_MAX_REDIRECTS   || 4
camo_hostname   = process.env.CAMO_HOSTNAME        || "unknown"
socket_timeout  = process.env.CAMO_SOCKET_TIMEOUT  || 10
logging_enabled = process.env.CAMO_LOGGING_ENABLED || "disabled"
keep_alive = process.env.CAMO_KEEP_ALIVE || "false"

content_length_limit = parseInt(process.env.CAMO_LENGTH_LIMIT || 5242880, 10)

accepted_image_mime_types = JSON.parse(Fs.readFileSync(
  Path.resolve(__dirname, "mime-types.json"),
  encoding: 'utf8'
))

debug_log = (msg) ->
  if logging_enabled == "debug"
    console.log("--------------------------------------------")
    console.log(msg)
    console.log("--------------------------------------------")

error_log = (msg) ->
  unless logging_enabled == "disabled"
    console.error("[#{new Date().toISOString()}] #{msg}")

total_connections   = 0
current_connections = 0
started_at          = new Date

default_security_headers =
  "X-Frame-Options": "deny"
  "X-XSS-Protection": "1; mode=block"
  "X-Content-Type-Options": "nosniff"
  "Content-Security-Policy": "default-src 'none'; img-src data:; style-src 'unsafe-inline'"
  "Strict-Transport-Security" : "max-age=31536000; includeSubDomains"

four_oh_four = (resp, msg, url) ->
  error_log "#{msg}: #{url?.format() or 'unknown'}"
  resp.writeHead 404,
    expires: "0"
    "Cache-Control": "no-cache, no-store, private, must-revalidate"
    "X-Frame-Options"           : default_security_headers["X-Frame-Options"]
    "X-XSS-Protection"          : default_security_headers["X-XSS-Protection"]
    "X-Content-Type-Options"    : default_security_headers["X-Content-Type-Options"]
    "Content-Security-Policy"   : default_security_headers["Content-Security-Policy"]
    "Strict-Transport-Security" : default_security_headers["Strict-Transport-Security"]

  finish resp, "Not Found"

finish = (resp, str) ->
  current_connections -= 1
  current_connections  = 0 if current_connections < 1
  resp.connection && resp.end str

process_url = (url, transferredHeaders, resp, remaining_redirects) ->
  if url.host?
    if url.protocol is 'https:'
      Protocol = Https
    else if url.protocol is 'http:'
      Protocol = Http
    else
      four_oh_four(resp, "Unknown protocol", url)
      return

    queryPath = url.pathname
    if url.query?
      queryPath += "?#{url.query}"

    transferredHeaders.host = url.host
    debug_log transferredHeaders

    requestOptions =
      hostname: url.hostname
      port: url.port
      path: queryPath
      headers: transferredHeaders

    if keep_alive == "false"
      requestOptions['agent'] = false

    srcReq = Protocol.get requestOptions, (srcResp) ->
      is_finished = true

      debug_log srcResp.headers

      content_length = srcResp.headers['content-length']

      if content_length > content_length_limit
        srcResp.destroy()
        four_oh_four(resp, "Content-Length exceeded", url)
      else
        newHeaders =
          'cache-control'             : srcResp.headers['cache-control'] || 'public, max-age=31536000'
          'Camo-Host'                 : camo_hostname
          'X-Frame-Options'           : default_security_headers['X-Frame-Options']
          'X-XSS-Protection'          : default_security_headers['X-XSS-Protection']
          'X-Content-Type-Options'    : default_security_headers['X-Content-Type-Options']
          'Content-Security-Policy'   : default_security_headers['Content-Security-Policy']
          'Strict-Transport-Security' : default_security_headers['Strict-Transport-Security']

        if srcContentType = srcResp.headers['content-type']
          newHeaders['content-type'] = srcContentType

        if eTag = srcResp.headers['etag']
          newHeaders['etag'] = eTag

        if expiresHeader = srcResp.headers['expires']
          newHeaders['expires'] = expiresHeader

        if lastModified = srcResp.headers['last-modified']
          newHeaders['last-modified'] = lastModified

        if origin = process.env.CAMO_TIMING_ALLOW_ORIGIN
          newHeaders['Timing-Allow-Origin'] = origin

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
              process_url newUrl, transferredHeaders, resp, remaining_redirects - 1
          when 304
            srcResp.destroy()
            resp.writeHead srcResp.statusCode, newHeaders
            finish resp
          else
            contentType = newHeaders['content-type']

            unless contentType?
              srcResp.destroy()
              four_oh_four(resp, "No content-type returned", url)
              return

            contentTypePrefix = contentType.split(";")[0].toLowerCase()

            unless contentTypePrefix in accepted_image_mime_types
              srcResp.destroy()
              four_oh_four(resp, "Non-Image content-type returned '#{contentTypePrefix}'", url)
              return

            debug_log newHeaders

            resp.writeHead srcResp.statusCode, newHeaders
            srcResp.pipe resp

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
  else
    four_oh_four(resp, "No host found " + url.host, url)

# decode a string of two char hex digits
hexdec = (str) ->
  if str and str.length > 0 and str.length % 2 == 0 and not str.match(/[^0-9a-f]/)
    buf = new Buffer(str.length / 2)
    for i in [0...str.length] by 2
      buf[i/2] = parseInt(str[i..i+1], 16)
    buf.toString()

server = Http.createServer (req, resp) ->
  if req.method != 'GET' || req.url == '/'
    resp.writeHead 200, default_security_headers
    resp.end 'hwhat'
  else if req.url == '/favicon.ico'
    resp.writeHead 200, default_security_headers
    resp.end 'ok'
  else if req.url == '/status'
    resp.writeHead 200, default_security_headers
    resp.end "ok #{current_connections}/#{total_connections} since #{started_at.toString()}"
  else
    total_connections   += 1
    current_connections += 1
    url = Url.parse req.url
    user_agent = process.env.CAMO_HEADER_VIA or= "Camo Asset Proxy #{version}"

    transferredHeaders =
      'Via'                     : user_agent
      'User-Agent'              : user_agent
      'Accept'                  : req.headers.accept ? 'image/*'
      'Accept-Encoding'         : req.headers['accept-encoding'] ? ''
      "X-Frame-Options"         : default_security_headers["X-Frame-Options"]
      "X-XSS-Protection"        : default_security_headers["X-XSS-Protection"]
      "X-Content-Type-Options"  : default_security_headers["X-Content-Type-Options"]
      "Content-Security-Policy" : default_security_headers["Content-Security-Policy"]

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

      try
        hmac.update(dest_url, 'utf8')
      catch error
        return four_oh_four(resp, "could not create checksum")

      hmac_digest = hmac.digest('hex')

      if hmac_digest == query_digest
        url = Url.parse dest_url

        process_url url, transferredHeaders, resp, max_redirects
      else
        four_oh_four(resp, "checksum mismatch #{hmac_digest}:#{query_digest}")
    else
      four_oh_four(resp, "No pathname provided on the server")

console.log "SSL-Proxy running on #{port} with node:#{process.version} pid:#{process.pid} version:#{version}."

server.listen port
