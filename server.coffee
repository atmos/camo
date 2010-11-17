Fs          = require 'fs'
Url         = require 'url'
Http        = require 'http'
Crypto      = require 'crypto'
QueryString = require 'querystring'

port       = parseInt process.env.PORT || 8081
version    = "0.2.2"
shared_key = process.env.CAMO_KEY      || '0x24FEEDFACEDEADBEEFCAFE'

log = (msg) ->
  console.log("--------------------------------------------")
  console.log(msg)
  console.log("--------------------------------------------")

server = Http.createServer (req, resp) ->
  if req.method != 'GET' || req.url == '/'
    resp.writeHead 200
    resp.end 'hwhat'
  else if req.url == '/favicon.ico'
    resp.writeHead 200
    resp.end 'ok'
  else
    url = Url.parse req.url

    four_oh_hour = (msg) ->
      log msg
      resp.writeHead 404, { }
      resp.write "Not Found"
      resp.end()

    transferred_headers =
      'Via'                    : process.env.CAMO_HEADER_VIA or= "Camo Asset Proxy #{version}"
      'Accept'                 : req.headers.accept
      'Accept-Encoding'        : req.headers['accept-encoding']
      'x-forwarded-for'        : req.headers['x-forwarded-for']
      'x-content-type-options' : 'nosniff'

    delete(req.headers.cookie)
    log(req.headers)

    query_digest = url.pathname.replace(/^\//, '')
    query_params = QueryString.parse(url.query)

    if url.pathname?
      hmac = Crypto.createHmac("sha1", shared_key)
      hmac.update(query_params.url)
      hmac_digest = hmac.digest('hex')

      if hmac_digest == query_digest
        url = Url.parse query_params.url

        if url.host?
          src = Http.createClient url.port || 80, url.hostname

          src.on 'error', (error) ->
            four_oh_hour("Client Request error #{error.stack}")

          query_path = url.pathname
          if url.query?
            query_path += "?#{url.query}"

          transferred_headers.host = url.host

          log transferred_headers

          srcReq = src.request 'GET', query_path, transferred_headers

          srcReq.on 'response', (srcResp) ->
            log srcResp.headers

            content_length  = srcResp.headers['content-length']

            if(content_length > 5242880)
              four_oh_hour("Content-Length exceeded")
            else
              newHeaders =
                'expires'                : srcResp.headers['expires']
                'content-type'           : srcResp.headers['content-type']
                'cache-control'          : srcResp.headers['cache-control']
                'content-length'         : content_length
                'X-Content-Type-Options' : 'nosniff'

              srcResp.on 'end', ->
                resp.end()

              srcResp.on 'error', ->
                resp.end()

              switch srcResp.statusCode
                when 200
                  if srcResp.statusCode == 200 && newHeaders['content-type'].slice(0, 5) != 'image'
                    four_oh_hour("Non-Image content-type returned")

                  log newHeaders

                  resp.writeHead srcResp.statusCode, newHeaders
                  srcResp.on 'data', (chunk) ->
                    resp.write chunk

                when 304
                  resp.writeHead srcResp.statusCode, newHeaders

                else
                  four_oh_hour("Responded with #{srcResp.statusCode}")

          srcReq.on 'error', ->
            resp.end()

          srcReq.end()

        else
          four_oh_hour("No host found")
      else
        four_oh_hour("checksum mismatch")
    else
      four_oh_hour("No pathname provided on the server")

console.log "SSL-Proxy running on #{port} with pid:#{process.pid}."
console.log "Using the secret key #{shared_key}"

Fs.open "tmp/camo.pid", "w", 0600, (err, fd) ->
  Fs.writeSync fd, process.pid

server.listen port
