vbulletin-utils
===============

This repo contains little bits that I've put together to help myself
fix issues on and operate a forum that sees 3M+ hits per month.

We run both HTTP and HTTPS with Varnish, with Nginx serving as both
the webserver and SSL termination point. HTTPS users are proxied locally
back through Varnish so they don't lose any of the benefits that of the
Varnish proxy.
