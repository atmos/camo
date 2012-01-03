(function() {
  var Crypto, EXCLUDED_HOSTS, Fs, Http, QueryString, RESTRICTED_IPS, Url, camo_hostname, current_connections, excluded, finish, four_oh_four, hexdec, log, logging_enabled, port, server, shared_key, started_at, total_connections, version;
  Fs = require('fs');
  Url = require('url');
  Http = require('http');
  Crypto = require('crypto');
  QueryString = require('querystring');
  port = parseInt(process.env.PORT || 8081);
  version = "0.3.0";
  excluded = process.env.CAMO_HOST_EXCLUSIONS || '*.example.org';
  shared_key = process.env.CAMO_KEY || '0x24FEEDFACEDEADBEEFCAFE';
  camo_hostname = process.env.CAMO_HOSTNAME || "unknown";
  logging_enabled = process.env.CAMO_LOGGING_ENABLED || "disabled";
  log = function(msg) {
    if (logging_enabled !== "disabled") {
      console.log("--------------------------------------------");
      console.log(msg);
      return console.log("--------------------------------------------");
    }
  };
  EXCLUDED_HOSTS = new RegExp(excluded.replace(".", "\\.").replace("*", "\\.*"));
  RESTRICTED_IPS = /^((10\.)|(127\.)|(169\.254)|(192\.168)|(172\.((1[6-9])|(2[0-9])|(3[0-1]))))/;
  total_connections = 0;
  current_connections = 0;
  started_at = new Date;
  four_oh_four = function(resp, msg) {
    log(msg);
    resp.writeHead(404);
    return finish(resp, "Not Found");
  };
  finish = function(resp, str) {
    current_connections -= 1;
    if (current_connections < 1) {
      current_connections = 0;
    }
    return resp.connection && resp.end(str);
  };
  hexdec = function(str) {
    var buf, i, _ref, _step;
    if (str && str.length > 0 && str.length % 2 === 0 && !str.match(/[^0-9a-f]/)) {
      buf = new Buffer(str.length / 2);
      for (i = 0, _ref = str.length, _step = 2; 0 <= _ref ? i < _ref : i > _ref; i += _step) {
        buf[i / 2] = parseInt(str.slice(i, (i + 1 + 1) || 9e9), 16);
      }
      return buf.toString();
    }
  };
  server = Http.createServer(function(req, resp) {
    var dest_url, encoded_url, hmac, hmac_digest, query_digest, query_path, src, srcReq, transferred_headers, url, url_type, _base, _ref;
    if (req.method !== 'GET' || req.url === '/') {
      resp.writeHead(200);
      return resp.end('hwhat');
    } else if (req.url === '/favicon.ico') {
      resp.writeHead(200);
      return resp.end('ok');
    } else if (req.url === '/status') {
      resp.writeHead(200);
      return resp.end("ok " + current_connections + "/" + total_connections + " since " + (started_at.toString()));
    } else {
      total_connections += 1;
      current_connections += 1;
      url = Url.parse(req.url);
      transferred_headers = {
        'Via': (_base = process.env).CAMO_HEADER_VIA || (_base.CAMO_HEADER_VIA = "Camo Asset Proxy " + version),
        'Accept': req.headers.accept,
        'Accept-Encoding': req.headers['accept-encoding'],
        'x-forwarded-for': req.headers['x-forwarded-for'],
        'x-content-type-options': 'nosniff'
      };
      delete req.headers.cookie;
      _ref = url.pathname.replace(/^\//, '').split("/", 2), query_digest = _ref[0], encoded_url = _ref[1];
      if (encoded_url = hexdec(encoded_url)) {
        url_type = 'path';
        dest_url = encoded_url;
      } else {
        url_type = 'query';
        dest_url = QueryString.parse(url.query).url;
      }
      log({
        type: url_type,
        url: req.url,
        headers: req.headers,
        dest: dest_url,
        digest: query_digest
      });
      if ((url.pathname != null) && dest_url) {
        hmac = Crypto.createHmac("sha1", shared_key);
        hmac.update(dest_url);
        hmac_digest = hmac.digest('hex');
        if (hmac_digest === query_digest) {
          url = Url.parse(dest_url);
          if ((url.host != null) && !url.host.match(RESTRICTED_IPS)) {
            if (url.host.match(EXCLUDED_HOSTS)) {
              return four_oh_four(resp, "Hitting excluded hostnames");
            }
            src = Http.createClient(url.port || 80, url.hostname);
            src.on('error', function(error) {
              return four_oh_four(resp, "Client Request error " + error.stack);
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
                return four_oh_four(resp, "Content-Length exceeded");
              } else {
                newHeaders = {
                  'expires': srcResp.headers['expires'],
                  'content-type': srcResp.headers['content-type'],
                  'cache-control': srcResp.headers['cache-control'],
                  'content-length': content_length,
                  'Camo-Host': camo_hostname,
                  'X-Content-Type-Options': 'nosniff'
                };
                
                if (srcResp.headers['content-encoding']) {
                  newHeaders['content-encoding'] = srcResp.headers['content-encoding'];
                }
                
                srcResp.on('end', function() {
                  return finish(resp);
                });
                srcResp.on('error', function() {
                  return finish(resp);
                });
                switch (srcResp.statusCode) {
                  case 200:
                    if (newHeaders['content-type'] && newHeaders['content-type'].slice(0, 5) !== 'image') {
                      four_oh_four(resp, "Non-Image content-type returned");
                    }
                    log(newHeaders);
                    resp.writeHead(srcResp.statusCode, newHeaders);
                    return srcResp.on('data', function(chunk) {
                      return resp.write(chunk);
                    });
                  case 304:
                    return resp.writeHead(srcResp.statusCode, newHeaders);
                  default:
                    return four_oh_four(resp, "Responded with " + srcResp.statusCode + ":" + srcResp.headers);
                }
              }
            });
            srcReq.on('error', function() {
              return finish(resp);
            });
            return srcReq.end();
          } else {
            return four_oh_four(resp, "No host found " + url.host);
          }
        } else {
          return four_oh_four(resp, "checksum mismatch " + hmac_digest + ":" + query_digest);
        }
      } else {
        return four_oh_four(resp, "No pathname provided on the server");
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
