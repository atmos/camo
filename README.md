![camo](http://farm5.static.flickr.com/4116/4857328881_fefb8e2134_z.jpg)

Camo is all about making insecure assets look secure.  This is an SSL image proxy to prevent mixed content warnings on secure pages served from [GitHub](https://github.com).

We want to allow people to keep embedding images in comments/issues/READMEs/google charting.

[There's more info on the GitHub blog](https://github.com/blog/743-sidejack-prevention-phase-3-ssl-proxied-assets).

Using a shared key, proxy URLs are encrypted with [hmac](http://en.wikipedia.org/wiki/HMAC) so we can bust caches/ban/rate limit if needed.

Camo currently runs on node version 0.4.10 at GitHub.

Features
--------

* Proxy google charts
* Proxy images under 5 MB
* Follow redirects to a configurable depth
* Proxy remote images with a content-type of `image/*`
* 404s for anything other than a 200, 301, 302 or 304 HTTP response
* Disallows proxying to private IP ranges

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

## Testing Functionality

### Start the server

    % coffee server.coffee

### In another shell

    % rake

### Debugging

To see the full URL resclient is hitting etc, try this.

    % RESTCLIENT_LOG=stdout rake

### Deployment

You can see an example [god config](https://gist.github.com/675038) here.

To enable useful line numbers in stacktraces you probably want to compile the server.coffee file to native javascript when deploying.

    % coffee -c server.coffee
    % /usr/bin/env PORT=9090 CAMO_KEY="<my application key>" node server.js
