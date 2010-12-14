(function() {
  var Crypto, Fs, Http, QueryString, RESTRICTED_IPS, Url, log, logging_enabled, port, server, shared_key, version;
  Fs = require('fs');
  Url = require('url');
  Http = require('http');
  Crypto = require('crypto');
  QueryString = require('querystring');
  port = parseInt(process.env.PORT || 8081);
  version = "0.3.0";
  shared_key = process.env.CAMO_KEY || '0x24FEEDFACEDEADBEEFCAFE';
  logging_enabled = process.env.CAMO_LOGGING_ENABLED || "disabled";
  log = function(msg) {
    if (logging_enabled !== "disabled") {
      console.log("--------------------------------------------");
      console.log(msg);
      return console.log("--------------------------------------------");
    }
  };
  RESTRICTED_IPS = /^(10\.)|(127\.)|(169\.254)|(192\.168)|(172\.(1[6-9])|(2[0-9])|(3[0-1]))/;
  server = Http.createServer(function(req, resp) {
    var four_oh_four, hmac, hmac_digest, query_digest, query_params, query_path, src, srcReq, transferred_headers, url, _base;
    if (req.method !== 'GET' || req.url === '/') {
      resp.writeHead(200);
      return resp.end('hwhat');
    } else if (req.url === '/favicon.ico') {
      resp.writeHead(200);
      return resp.end('ok');
    } else {
      url = Url.parse(req.url);
      four_oh_four = function(msg) {
        log(msg);
        resp.writeHead(404, {});
        resp.write("Not Found");
        return resp.end();
      };
      transferred_headers = {
        'Via': (_base = process.env).CAMO_HEADER_VIA || (_base.CAMO_HEADER_VIA = "Camo Asset Proxy " + version),
        'Accept': req.headers.accept,
        'Accept-Encoding': req.headers['accept-encoding'],
        'x-forwarded-for': req.headers['x-forwarded-for'],
        'x-content-type-options': 'nosniff'
      };
      delete req.headers.cookie;
      log(req.headers);
      query_digest = url.pathname.replace(/^\//, '');
      query_params = QueryString.parse(url.query);
      if (url.pathname != null) {
        hmac = Crypto.createHmac("sha1", shared_key);
        hmac.update(query_params.url);
        hmac_digest = hmac.digest('hex');
        if (hmac_digest === query_digest) {
          url = Url.parse(query_params.url);
          if ((url.host != null) && !url.host.match(RESTRICTED_IPS)) {
            src = Http.createClient(url.port || 80, url.hostname);
            src.on('error', function(error) {
              return four_oh_four("Client Request error " + error.stack);
            });
            query_path = url.pathname;
            if (url.query != null) {
              query_path += "?" + url.query;
            }
            transferred_headers.host = url.host;
            log(transferred_headers);
            srcReq = src.request('GET', query_path, transferred_headers);
            srcReq.on('response', function(srcResp) {
              var content_length, newHeaders;
              log(srcResp.headers);
              content_length = srcResp.headers['content-length'];
              if (content_length > 5242880) {
                return four_oh_four("Content-Length exceeded");
              } else {
                newHeaders = {
                  'expires': srcResp.headers['expires'],
                  'content-type': srcResp.headers['content-type'],
                  'cache-control': srcResp.headers['cache-control'],
                  'content-length': content_length,
                  'X-Content-Type-Options': 'nosniff'
                };
                srcResp.on('end', function() {
                  return resp.end();
                });
                srcResp.on('error', function() {
                  return resp.end();
                });
                switch (srcResp.statusCode) {
                  case 200:
                    if (newHeaders['content-type'] && newHeaders['content-type'].slice(0, 5) !== 'image') {
                      four_oh_four("Non-Image content-type returned");
                    }
                    log(newHeaders);
                    resp.writeHead(srcResp.statusCode, newHeaders);
                    return srcResp.on('data', function(chunk) {
                      return resp.write(chunk);
                    });
                    break;
                  case 304:
                    return resp.writeHead(srcResp.statusCode, newHeaders);
                  default:
                    return four_oh_four("Responded with " + srcResp.statusCode + ":" + srcResp.headers);
                }
              }
            });
            srcReq.on('error', function() {
              return resp.end();
            });
            return srcReq.end();
          } else {
            return four_oh_four("No host found " + url.host);
          }
        } else {
          return four_oh_four("checksum mismatch " + hmac_digest + ":" + query_digest);
        }
      } else {
        return four_oh_four("No pathname provided on the server");
      }
    }
  });
  console.log("SSL-Proxy running on " + port + " with pid:" + process.pid + ".");
  console.log("Using the secret key " + shared_key);
  Fs.open("tmp/camo.pid", "w", 0600, function(err, fd) {
    return Fs.writeSync(fd, process.pid);
  });
  server.listen(port);
}).call(this);
