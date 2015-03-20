// Generated by CoffeeScript 1.9.1
(function() {
  var Crypto, Fs, Http, Https, Path, QueryString, Url, accepted_image_mime_types, camo_hostname, content_length_limit, current_connections, debug_log, default_security_headers, detect_content_type, detect_content_type_buffer_size, error_log, finish, four_oh_four, hexdec, keep_alive, logging_enabled, max_redirects, mmm, mmmagic, port, process_url, server, shared_key, socket_timeout, started_at, stream, total_connections, version, zlib,
    indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  Fs = require('fs');

  Path = require('path');

  Url = require('url');

  Http = require('http');

  Https = require('https');

  Crypto = require('crypto');

  QueryString = require('querystring');

  stream = require('stream');

  zlib = require('zlib');

  mmm = null;

  port = parseInt(process.env.PORT || 8081, 10);

  version = require(Path.resolve(__dirname, "package.json")).version;

  shared_key = process.env.CAMO_KEY || '0x24FEEDFACEDEADBEEFCAFE';

  max_redirects = process.env.CAMO_MAX_REDIRECTS || 4;

  camo_hostname = process.env.CAMO_HOSTNAME || "unknown";

  socket_timeout = process.env.CAMO_SOCKET_TIMEOUT || 10;

  logging_enabled = process.env.CAMO_LOGGING_ENABLED || "disabled";

  keep_alive = process.env.CAMO_KEEP_ALIVE || "false";

  detect_content_type = process.env.CAMO_DETECT_CONTENT_TYPE || "disabled";

  detect_content_type_buffer_size = process.env.CAMO_DETECT_CONTENT_TYPE_BUFFER_SIZE || 100;

  content_length_limit = parseInt(process.env.CAMO_LENGTH_LIMIT || 5242880, 10);

  if (detect_content_type === "enabled") {
    mmmagic = require('mmmagic');
    mmm = new mmmagic.Magic(mmmagic.MAGIC_MIME);
  }

  accepted_image_mime_types = JSON.parse(Fs.readFileSync(Path.resolve(__dirname, "mime-types.json"), {
    encoding: 'utf8'
  }));

  debug_log = function(msg) {
    if (logging_enabled === "debug") {
      console.log("--------------------------------------------");
      console.log(msg);
      return console.log("--------------------------------------------");
    }
  };

  error_log = function(msg) {
    if (logging_enabled !== "disabled") {
      return console.error("[" + (new Date().toISOString()) + "] " + msg);
    }
  };

  total_connections = 0;

  current_connections = 0;

  started_at = new Date;

  default_security_headers = {
    "X-Frame-Options": "deny",
    "X-XSS-Protection": "1; mode=block",
    "X-Content-Type-Options": "nosniff",
    "Content-Security-Policy": "default-src 'none'; img-src data:; style-src 'unsafe-inline'",
    "Strict-Transport-Security": "max-age=31536000; includeSubDomains"
  };

  four_oh_four = function(resp, msg, url) {
    error_log(msg + ": " + ((url != null ? url.format() : void 0) || 'unknown'));
    resp.writeHead(404, {
      expires: "0",
      "Cache-Control": "no-cache, no-store, private, must-revalidate",
      "X-Frame-Options": default_security_headers["X-Frame-Options"],
      "X-XSS-Protection": default_security_headers["X-XSS-Protection"],
      "X-Content-Type-Options": default_security_headers["X-Content-Type-Options"],
      "Content-Security-Policy": default_security_headers["Content-Security-Policy"],
      "Strict-Transport-Security": default_security_headers["Strict-Transport-Security"]
    });
    return finish(resp, "Not Found");
  };

  finish = function(resp, str) {
    current_connections -= 1;
    if (current_connections < 1) {
      current_connections = 0;
    }
    return resp.connection && resp.end(str);
  };

  process_url = function(url, transferredHeaders, resp, remaining_redirects) {
    var Protocol, queryPath, requestOptions, srcReq;
    if (url.host != null) {
      if (url.protocol === 'https:') {
        Protocol = Https;
      } else if (url.protocol === 'http:') {
        Protocol = Http;
      } else {
        four_oh_four(resp, "Unknown protocol", url);
        return;
      }
      queryPath = url.pathname;
      if (url.query != null) {
        queryPath += "?" + url.query;
      }
      transferredHeaders.host = url.host;
      debug_log(transferredHeaders);
      requestOptions = {
        hostname: url.hostname,
        port: url.port,
        path: queryPath,
        headers: transferredHeaders
      };
      if (keep_alive === "false") {
        requestOptions['agent'] = false;
      }
      srcReq = Protocol.get(requestOptions, function(srcResp) {
        var contentType, content_length, dataRead, decodeStream, decoder, detectContentType, eTag, expiresHeader, is_finished, lastModified, newHeaders, newUrl, origin, sendResponse;
        is_finished = true;
        debug_log(srcResp.headers);
        content_length = srcResp.headers['content-length'];
        if (content_length > content_length_limit) {
          srcResp.destroy();
          return four_oh_four(resp, "Content-Length exceeded", url);
        } else {
          newHeaders = {
            'content-type': srcResp.headers['content-type'],
            'cache-control': srcResp.headers['cache-control'] || 'public, max-age=31536000',
            'Camo-Host': camo_hostname,
            'X-Frame-Options': default_security_headers['X-Frame-Options'],
            'X-XSS-Protection': default_security_headers['X-XSS-Protection'],
            'X-Content-Type-Options': default_security_headers['X-Content-Type-Options'],
            'Content-Security-Policy': default_security_headers['Content-Security-Policy'],
            'Strict-Transport-Security': default_security_headers['Strict-Transport-Security']
          };
          if (eTag = srcResp.headers['etag']) {
            newHeaders['etag'] = eTag;
          }
          if (expiresHeader = srcResp.headers['expires']) {
            newHeaders['expires'] = expiresHeader;
          }
          if (lastModified = srcResp.headers['last-modified']) {
            newHeaders['last-modified'] = lastModified;
          }
          if (origin = process.env.CAMO_TIMING_ALLOW_ORIGIN) {
            newHeaders['Timing-Allow-Origin'] = origin;
          }
          if (content_length != null) {
            newHeaders['content-length'] = content_length;
          }
          if (srcResp.headers['transfer-encoding']) {
            newHeaders['transfer-encoding'] = srcResp.headers['transfer-encoding'];
          }
          if (srcResp.headers['content-encoding']) {
            newHeaders['content-encoding'] = srcResp.headers['content-encoding'];
          }
          srcResp.on('end', function() {
            if (is_finished) {
              return finish(resp);
            }
          });
          srcResp.on('error', function() {
            if (is_finished) {
              return finish(resp);
            }
          });
          switch (srcResp.statusCode) {
            case 200:
              contentType = newHeaders['content-type'];
              dataRead = new Buffer(0);
              decodeStream = function(chunk) {
                dataRead = Buffer.concat([dataRead, chunk]);
                return decoder.write(chunk);
              };
              sendResponse = function(contentType, srcResp, resp, url, decodeStream) {
                var contentTypePrefix;
                if (contentType == null) {
                  srcResp.destroy();
                  four_oh_four(resp, "No content-type returned", url);
                  return;
                }
                contentTypePrefix = contentType.split(";")[0];
                if (indexOf.call(accepted_image_mime_types, contentTypePrefix) < 0) {
                  srcResp.destroy();
                  four_oh_four(resp, "Non-Image content-type returned '" + contentTypePrefix + "'", url);
                  return;
                }
                newHeaders['content-type'] = contentType;
                debug_log(newHeaders);
                resp.writeHead(srcResp.statusCode, newHeaders);
                srcResp.removeListener('data', decodeStream);
                srcResp.resume();
                return srcResp.pipe(resp);
              };
              if (mmm) {
                debug_log("Auto-detecting content type");
                decoder = new stream.PassThrough();
                switch (srcResp.headers['content-encoding']) {
                  case 'gzip':
                    debug_log("Using gzip decoder");
                    decoder = zlib.createGunzip();
                    break;
                  case 'deflate':
                    debug_log("Using deflate decoder");
                    decoder = zlib.createInflate();
                    break;
                  default:
                    debug_log("Using no-op decoder");
                }
                detectContentType = function(chunk) {
                  srcResp.pause();
                  decoder.end();
                  srcResp.unshift(dataRead);
                  debug_log("Detecting for chunk");
                  return mmm.detect(chunk, function(err, result) {
                    var detectedContentType;
                    if (err) {
                      error_log("Error detecting content type from first decoded data chunk for url: " + url);
                      error_log(err);
                    } else {
                      detectedContentType = result;
                    }
                    debug_log('Given content-type: "' + contentType + '" detected content-type: "' + detectedContentType + '"');
                    if (detectedContentType) {
                      return sendResponse(detectedContentType, srcResp, resp, url, decodeStream);
                    } else {
                      return sendResponse(contentType, srcResp, resp, url, decodeStream);
                    }
                  });
                };
                decoder.once('data', detectContentType);
                return srcResp.on('data', decodeStream);
              } else {
                return sendResponse(contentType, srcResp, resp, url, decodeStream);
              }
              break;
            case 301:
            case 302:
            case 303:
            case 307:
              srcResp.destroy();
              if (remaining_redirects <= 0) {
                return four_oh_four(resp, "Exceeded max depth", url);
              } else if (!srcResp.headers['location']) {
                return four_oh_four(resp, "Redirect with no location", url);
              } else {
                is_finished = false;
                newUrl = Url.parse(srcResp.headers['location']);
                if (!((newUrl.host != null) && (newUrl.hostname != null))) {
                  newUrl.host = newUrl.hostname = url.hostname;
                  newUrl.protocol = url.protocol;
                }
                debug_log("Redirected to " + (newUrl.format()));
                return process_url(newUrl, transferredHeaders, resp, remaining_redirects - 1);
              }
              break;
            case 304:
              srcResp.destroy();
              return resp.writeHead(srcResp.statusCode, newHeaders);
            default:
              srcResp.destroy();
              return four_oh_four(resp, "Origin responded with " + srcResp.statusCode, url);
          }
        }
      });
      srcReq.setTimeout(socket_timeout * 1000, function() {
        srcReq.abort();
        return four_oh_four(resp, "Socket timeout", url);
      });
      srcReq.on('error', function(error) {
        return four_oh_four(resp, "Client Request error " + error.stack, url);
      });
      resp.on('close', function() {
        error_log("Request aborted");
        return srcReq.abort();
      });
      return resp.on('error', function(e) {
        error_log("Request error: " + e);
        return srcReq.abort();
      });
    } else {
      return four_oh_four(resp, "No host found " + url.host, url);
    }
  };

  hexdec = function(str) {
    var buf, i, j, ref;
    if (str && str.length > 0 && str.length % 2 === 0 && !str.match(/[^0-9a-f]/)) {
      buf = new Buffer(str.length / 2);
      for (i = j = 0, ref = str.length; j < ref; i = j += 2) {
        buf[i / 2] = parseInt(str.slice(i, +(i + 1) + 1 || 9e9), 16);
      }
      return buf.toString();
    }
  };

  server = Http.createServer(function(req, resp) {
    var base, dest_url, encoded_url, error, hmac, hmac_digest, query_digest, ref, ref1, transferredHeaders, url, url_type, user_agent;
    if (req.method !== 'GET' || req.url === '/') {
      resp.writeHead(200, default_security_headers);
      return resp.end('hwhat');
    } else if (req.url === '/favicon.ico') {
      resp.writeHead(200, default_security_headers);
      return resp.end('ok');
    } else if (req.url === '/status') {
      resp.writeHead(200, default_security_headers);
      return resp.end("ok " + current_connections + "/" + total_connections + " since " + (started_at.toString()));
    } else {
      total_connections += 1;
      current_connections += 1;
      url = Url.parse(req.url);
      user_agent = (base = process.env).CAMO_HEADER_VIA || (base.CAMO_HEADER_VIA = "Camo Asset Proxy " + version);
      transferredHeaders = {
        'Via': user_agent,
        'User-Agent': user_agent,
        'Accept': (ref = req.headers.accept) != null ? ref : 'image/*',
        'Accept-Encoding': req.headers['accept-encoding'],
        "X-Frame-Options": default_security_headers["X-Frame-Options"],
        "X-XSS-Protection": default_security_headers["X-XSS-Protection"],
        "X-Content-Type-Options": default_security_headers["X-Content-Type-Options"],
        "Content-Security-Policy": default_security_headers["Content-Security-Policy"]
      };
      delete req.headers.cookie;
      ref1 = url.pathname.replace(/^\//, '').split("/", 2), query_digest = ref1[0], encoded_url = ref1[1];
      if (encoded_url = hexdec(encoded_url)) {
        url_type = 'path';
        dest_url = encoded_url;
      } else {
        url_type = 'query';
        dest_url = QueryString.parse(url.query).url;
      }
      debug_log({
        type: url_type,
        url: req.url,
        headers: req.headers,
        dest: dest_url,
        digest: query_digest
      });
      if (req.headers['via'] && req.headers['via'].indexOf(user_agent) !== -1) {
        return four_oh_four(resp, "Requesting from self");
      }
      if ((url.pathname != null) && dest_url) {
        hmac = Crypto.createHmac("sha1", shared_key);
        try {
          hmac.update(dest_url, 'utf8');
        } catch (_error) {
          error = _error;
          return four_oh_four(resp, "could not create checksum");
        }
        hmac_digest = hmac.digest('hex');
        if (hmac_digest === query_digest) {
          url = Url.parse(dest_url);
          return process_url(url, transferredHeaders, resp, max_redirects);
        } else {
          return four_oh_four(resp, "checksum mismatch " + hmac_digest + ":" + query_digest);
        }
      } else {
        return four_oh_four(resp, "No pathname provided on the server");
      }
    }
  });

  console.log("SSL-Proxy running on " + port + " with pid:" + process.pid + " version:" + version + ".");

  server.listen(port);

}).call(this);
