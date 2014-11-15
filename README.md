# camo [![Build Status](https://travis-ci.org/atmos/camo.svg?branch=master)](https://travis-ci.org/atmos/camo)

Camo is all about making insecure assets look secure.  This is an SSL image proxy to prevent mixed content warnings on secure pages served from [GitHub](https://github.com).

![camo](https://f.cloud.github.com/assets/38/2496172/f558bbb4-b312-11e3-88e9-646b77e47e6e.gif)

We want to allow people to keep embedding images in comments/issues/READMEs.

[There's more info on the GitHub blog](https://github.com/blog/743-sidejack-prevention-phase-3-ssl-proxied-assets).

Using a shared key, proxy URLs are encrypted with [hmac](http://en.wikipedia.org/wiki/HMAC) so we can bust caches/ban/rate limit if needed.

Camo currently runs on node version 0.10.26 at GitHub on [heroku](http://heroku.com).

[![Launch on Heroku](https://www.herokucdn.com/deploy/button.png)](https://heroku.com/deploy?template=https://github.com/atmos/camo)

Features
--------

* Max size for proxied images
* Follow redirects to a certain depth
* Restricts proxied images content-types to a whitelist
* 404s for anything other than a 200, 301, 302, 303, 304 or 307 HTTP response

At GitHub we render markdown and replace all of the `src` attributes on the `img` tags with the appropriate URL to hit the proxies.  There's example code for creating URLs in [the tests](https://github.com/atmos/camo/blob/master/test/proxy_test.rb).

## URL Formats

Camo supports two distinct URL formats:

    http://example.org/<digest>?url=<image-url>
    http://example.org/<digest>/<image-url>

The `<digest>` is a 40 character hex encoded HMAC digest generated with a shared
secret key and the unescaped `<image-url>` value. The `<image-url>` is the
absolute URL locating an image. In the first format, the `<image-url>` should be
URL escaped aggressively to ensure the original value isn't mangled in transit.
In the second format, each byte of the `<image-url>` should be hex encoded such
that the resulting value includes only characters `[0-9a-f]`.

### Generating image URLs in Ruby

```ruby
require 'uri'
require 'openssl'

digest = OpenSSL::Digest.new('sha1')
host = "https://sample-app-name.herokuapp.com"
secret = "MySharedSecretKey"

image_url = "http://a1.dspnimg.com/data/l/1099218875447_anbzQlVe_l.jpg"
encoded_image_url = URI.encode_www_form_component(image_url)

hexdigest = OpenSSL::HMAC.hexdigest(digest, secret, image_url)

uri = URI.parse("#{host}/#{hexdigest}")
uri.query = "url=#{encoded_image_url}"

puts uri.to_s  # => "https://sample-app-name.herokuapp.com/eb56b6821137216907731f1ddbd4d9fa0ee88e14?url=http%3A%2F%2Fa1.dspnimg.com%2Fdata%2Fl%2F1099218875447_anbzQlVe_l.jpg"
```

## Configuration

Camo is configured through environment variables.

* `PORT`: The port number Camo should listen on. (default: 8081)
* `CAMO_HEADER_VIA`: The string for Camo to include in the `Via` and `User-Agent` headers it sends in requests to origin servers. (default: `Camo Asset Proxy <version>`)
* `CAMO_KEY`: The shared key used to generate the HMAC digest.
* `CAMO_LENGTH_LIMIT`: The maximum `Content-Length` Camo will proxy. (default: 5242880)
* `CAMO_LOGGING_ENABLED`: The logging level used for reporting debug or error information. Options are `debug` and `disabled`. (default: `disabled`)
* `CAMO_MAX_REDIRECTS`: The maximum number of redirects Camo will follow while fetching an image. (default: 4)
* `CAMO_SOCKET_TIMEOUT`: The maximum number of seconds Camo will wait before giving up on fetching an image. (default: 10)
* `CAMO_TIMING_ALLOW_ORIGIN`: The string for Camo to include in the [`Timing-Allow-Origin` header](http://www.w3.org/TR/resource-timing/#cross-origin-resources) it sends in responses to clients. The header is omitted if this environment variable is not set. (default: not set)

## Testing Functionality

### Bundle Everything

    % rake bundle

### Start the server

    % coffee server.coffee

### In another shell

    % rake

### Debugging

To see the full URL restclient is hitting etc, try this.

    % RESTCLIENT_LOG=stdout rake

### Deployment

You should run this on heroku.

To enable useful line numbers in stacktraces you probably want to compile the server.coffee file to native javascript when deploying.

    % coffee -c server.coffee
    % /usr/bin/env PORT=9090 CAMO_KEY="<my application key>" node server.js
