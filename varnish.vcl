backend default {
  .host = "127.0.0.1";
  .port = "8082";
}

acl purge {
  "localhost";
}

# We're running Nginx as our SSL termination point in front of
# Varnish. This way, SSL users still get the benefits of Varnish,
# and we don't have to maintain a separate application.
acl nginx_ssl {
  "127.0.0.1";
}

# This is for if you're behind another edge load balancer that
# sends the XFF header.
#acl edge_lb {
#  "xxx.xxx.xxx.xxx";
#}

sub vcl_recv {
  if (client.ip ~ nginx_ssl && req.http.X-Forwarded-Proto) {
    set req.http.X-Forwarded-Proto = "HTTPS";
  }

  if (client.ip ~ nginx_ssl && req.http.X-Forwarded-For) {
    set req.http.X-Forwarded-For = req.http.X-Forwarded-For;
#  } else if (client.ip ~ edge_lb && req.http.X-Forwarded-For) {
#    set req.http.X-Forwarded-For = req.http.X-Forwarded-For;
  } else {
    set req.http.X-Forwarded-For = regsub(client.ip, ":.*", "");
  }

  if (req.backend.healthy) {
    set req.grace = 30s;
  } else {
    set req.grace = 2m;
  }

  if (req.request == "PURGE") {
    if (!client.ip ~ purge) {
      error 405 "Not allowed";
    }
    return (lookup);
  }

  if (req.url ~ "^/login\.php" ||
      req.url ~ "^/register\.php" ||
      req.url ~ "^/usercp\.php" ||
      req.url ~ "^/private\.php" ||
      req.url ~ "^/profile\.php" ||
      req.url ~ "^/admincp") {
    return (pass);
  }
    
  if (req.url ~ "\.(css|js|jpg|jpeg|gif|ico|png)\??\d*$") {
    unset req.http.cookie;
    return (lookup);
  }
    
  # Change bb_ to your cookie prefix
  else {
    if (req.http.cookie ~ "bb_imloggedin=yes" ||
        req.http.cookie ~ "bb_userid" ||
        req.url ~ "\?(.*\&)?s=[a-fA-F0-9]{32}(\&|$)" ||
        req.http.cookie ~ "bb_password") {
      return (pass);
    } else {
      unset req.http.cookie;
    }
  }

  if (req.request != "GET" &&
      req.request != "HEAD" &&
      req.request != "PUT" &&
      req.request != "POST" &&
      req.request != "TRACE" &&
      req.request != "OPTIONS" &&
      req.request != "DELETE") {
    return (pipe);
  }

  if (req.request != "GET" && req.request != "HEAD") {
    return (pass);
  }
  return (lookup);
}

sub vcl_deliver {
  if (obj.hits > 0) {
    set resp.http.X-Cache = "HIT";
  } else {
    set resp.http.X-Cache = "MISS";
  }

  if (resp.http.magicmarker) {
    unset resp.http.magicmarker;
    set resp.http.age = "0";
  }
}

sub vcl_fetch {
  if (req.url ~ "\.(css|js|jpg|jpeg|gif|ico|png)\??\d*$") {
    unset beresp.http.expires;
    set beresp.http.cache-control = "max-age = 6048001";
    set beresp.ttl = 1w;
    set beresp.http.magicmarker = "1";
    set beresp.http.cacheable = "1";
    return(deliver);
  }
}

sub vcl_hash {

  hash_data(req.url);
  if (req.http.host) {
    hash_data(req.http.host);
  } else {
    hash_data(server.ip);
  }

  if (req.http.X-Forwarded-Proto) {
    hash_data(req.http.X-Forwarded-Proto);
  }

  return (hash);
}
