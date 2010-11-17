Fs          = require 'fs'
Url         = require 'url'
Http        = require 'http'
Crypto      = require 'crypto'
QueryString = require 'querystring'

port       = parseInt process.env.PORT || 8081
shared_key = process.env.CAMO_KEY      || '0x24FEEDFACEDEADBEEFCAFE'

server = Http.createServer (req, resp) ->
  if req.method != 'GET' || req.url == '/'
    resp.writeHead 200
    resp.end 'hwhat'
  else if req.url == '/favicon.ico'
    resp.writeHead 200
    resp.end 'ok'
  else
    url = Url.parse req.url

    transferred_headers =
      'Via'                    : 'GitHub Asset Proxy'
      'Accept'                 : req.headers.accept
      'Accept-Encoding'        : req.headers['accept-encoding']
      'x-forwarded-for'        : req.headers['x-forwarded-for']
      'x-content-type-options' : 'nosniff'

    delete(req.headers.cookie)
    console.log("--------------------------------------------")
    console.log(req.headers)
    console.log("--------------------------------------------")

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
            console.log("Client Request error #{error.stack}")
            resp.writeHead 404, { }
            resp.write "Not Found"
            resp.end()

          query_path = url.pathname
          if url.query?
            query_path += "?#{url.query}"

          transferred_headers.host = url.host

          console.log("--------------------------------------------")
          console.log(transferred_headers)
          console.log("--------------------------------------------")

          srcReq = src.request 'GET', query_path, transferred_headers

          srcReq.on 'response', (srcResp) ->
            console.log url

            console.log("--------------------------------------------")
            console.log srcResp.headers
            console.log("--------------------------------------------")

            content_length  = srcResp.headers['content-length']

            if(content_length > 5242880)
              resp.writeHead 404, { }
              resp.write "Not Found"
              resp.end()
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
                    console.log("Non-Image content-type returned")
                    resp.writeHead 404, { }
                    resp.write "Not Found"
                    resp.end()

                  console.log("--------------------------------------------")
                  console.log(newHeaders)
                  console.log("--------------------------------------------")

                  resp.writeHead srcResp.statusCode, newHeaders
                  srcResp.on 'data', (chunk) ->
                    resp.write chunk

                when 304
                  resp.writeHead srcResp.statusCode, newHeaders

                else
                  console.log("Responded with #{srcResp.statusCode}")
                  resp.writeHead 404, { }
                  resp.write "Not Found"
                  resp.end()

          srcReq.on 'error', ->
            resp.end()

          srcReq.end()

        else
          console.log("No host found")
          resp.writeHead 404, { }
          resp.write "Not Found"
          resp.end()
      else
        console.log("checksum mismatch")
        console.log("hmac_digest: '#{hmac_digest}'")
        console.log("query_digest:'#{query_digest}'")

        resp.writeHead 404, { }
        resp.write "Not Found"
        resp.end()
    else
      console.log("No pathname provided on the server")
      resp.writeHead 404, { }
      resp.write "Not Found"
      resp.end()

console.log "SSL-Proxy running on #{port} with pid:#{process.pid}."
console.log "Using the secret key #{shared_key}"

Fs.open "tmp/camo.pid", "w", 0666, (err, fd) ->
  Fs.writeSync fd, process.pid

server.listen port
