Fs          = require 'fs'
Url         = require 'url'
Http        = require 'http'
Crypto      = require 'crypto'
QueryString = require 'querystring'

port        = parseInt process.env.PORT  || 8081
shared_key  = process.env.CAMOUFLAGE_KEY || '0x24FEEDFACEDEADBEEFCAFE'

server = Http.createServer (req, resp) ->
  if req.method != 'GET' || req.url == '/'
    resp.writeHead 200
    resp.end 'hwhat'
  else if req.url == '/favicon.ico'
    resp.writeHead 200
    resp.end 'ok'
  else
    url = Url.parse req.url

    query_digest = url.pathname.replace(/^\//, '')
    query_params = QueryString.parse(url.query)

    if url.pathname?
      hmac = Crypto.createHmac("sha1", shared_key)
      hmac.update(query_params.url)
      hmac_digest = hmac.digest('hex')

      if hmac_digest == query_digest
        url = Url.parse query_params.url

        if url.host?
          src        = Http.createClient url.port || 80, url.host

          query_path = url.pathname
          if url.query?
            query_path += "?#{url.query}"

          req.headers.host = url.host
          delete(req.headers['connection'])

          srcReq = src.request 'GET', query_path, req.headers

          srcReq.on 'response', (srcResp) ->
            console.log url
            console.log srcResp.headers

            content_length = parseInt(srcResp.headers['content-length'])

            # don't pass cookies on
            delete(srcResp.headers['set-cookie'])
            srcResp.headers['X-Content-Type-Options'] = 'nosniff'

            if(content_length > 5242880)
              resp.writeHead 404, { }
              resp.write "Not Found"
              resp.end()
            else
              resp.writeHead srcResp.statusCode, srcResp.headers
              srcResp.on 'data', (chunk) ->
                resp.write chunk

              srcResp.on 'end', ->
                resp.end()

              srcResp.on 'error', ->
                resp.end()

          srcReq.on 'error', ->
            resp.end()

          srcReq.end()

        else
          resp.writeHead 404, { }
          resp.write "Not Found"
          resp.end()
      else
        resp.writeHead 404, { }
        resp.write "Not Found"
        resp.end()
    else
      resp.writeHead 404, { }
      resp.write "Not Found"
      resp.end()

console.log "SSL-Proxy running on #{port} with pid:#{process.pid}."
console.log "Using the secret key #{shared_key}"

Fs.open "tmp/camouflage.pid", "w", 0666, (err, fd) ->
  Fs.writeSync fd, process.pid

server.listen port
