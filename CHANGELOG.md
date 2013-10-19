1.1.3
=====

* [Address ddos](https://groups.google.com/forum/#!msg/nodejs/NEbweYB0ei0/gWvyzCunYjsJ?mkt_tok=3RkMMJWWfF9wsRonuavPZKXonjHpfsX54%2B8tXaO3lMI%2F0ER3fOvrPUfGjI4ASMFrI%2BSLDwEYGJlv6SgFQrjAMapmyLgLUhE%3D) in earlier versions of node.

1.1.1
=====

* Use pipe() to pause buffers when streaming to slow clients
* Fixup tests and Gemfile related stuff
* Workaround recent heroku changes that now detect camo as a ruby app due to Gemfile presence
* Ensure a location header is present before following redirects, fixes a crash

1.0.5
=====

* Fixup redirect loops where following redirects goes back to camo
* Add Fallback Accept headers for type `image/*`
* Fixup issues with chunked encoding responses
* Explicitly set User-Agent headers when proxying

1.0.2
=====

* Follow 303s and 307s now too

0.5.0
=====

* Follow redirects to a configurable depth

