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

