# camo

![camo](http://farm5.static.flickr.com/4116/4857328881_fefb8e2134_z.jpg)

Camouflage is all about making insecure assets looks secure.  This is an SSL image proxy to prevent mixed content warnings on secure pages served from [github](https://github.com).

We wanted to allow people to keep embedding image links in their comments and README files.  This also handles inlining google charts images.

[More Info Here](https://github.com/blog/743-sidejack-prevention-phase-3-ssl-proxied-assets)

We share a key between this proxy and the GitHub main app.  We encrypt the URL with [hmac](http://en.wikipedia.org/wiki/HMAC) so we're not an open proxy.  These keys come from the shell environment and are unique per deployment environment.  I'm not 100% sure this step is necessary.

When the GitHub app renders markdown it replaces all of the `src` attributes on any `img` tags with the an appropriate URL to hit the proxies.

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

To enable useful line numbers in stacktraces you probably want to
compile the server.coffee file to native javascript when deploy

    % coffee -c server.coffee
    % node server.js
