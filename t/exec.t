# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (2 * blocks() + 1);

#$Test::Nginx::LWP::LogLevel = 'debug';

run_tests();

__DATA__

=== TEST 1: exec normal location
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /main {
        echo_exec /bar;
        echo end;
    }
    location = /bar {
        echo "$echo_request_uri:";
        echo bar;
    }
--- request
    GET /main
--- response_body
/bar:
bar



=== TEST 2: location with args (inlined in uri)
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /main {
        echo_exec /bar?a=32;
        echo end;
    }
    location /bar {
        echo "a: [$arg_a]";
    }
--- request
    GET /main
--- response_body
a: [32]



=== TEST 3: location with args (in separate arg)
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /main {
        echo_exec /bar a=56;
        echo end;
    }
    location /bar {
        echo "a: [$arg_a]";
    }
--- request
    GET /main
--- response_body
a: [56]



=== TEST 4: exec named location
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /main {
        echo_exec @bar;
        echo end;
    }
    location @bar {
        echo bar;
    }
--- request
    GET /main
--- response_body
bar



=== TEST 5: query string ignored for named locations
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /main {
        echo_exec @bar?a=32;
        echo end;
    }
    location @bar {
        echo "a: [$arg_a]";
    }
--- request
    GET /main
--- response_body
a: []
--- error_log
querystring a=32 ignored when exec'ing named location @bar



=== TEST 6: query string ignored for named locations
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
  location /foo {
      echo_exec @bar;
  }
  location @bar {
      echo "uri: [$echo_request_uri]";
  }
--- request
    GET /foo
--- response_body
uri: [/foo]



=== TEST 7: exec(named location) in subrequests
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /entry {
        echo_location /foo;
        echo_sleep 0.001;
        echo_location /foo2;
    }
  location /foo {
      echo_exec @bar;
  }
  location /foo2 {
      echo_exec @bar;
  }

  location @bar {
    proxy_pass http://127.0.0.1:$server_port/bar;
  }
  location /bar {
    echo_sleep 0.01;
    echo hello;
  }
--- request
    GET /entry
--- response_body
hello
hello



=== TEST 8: exec(normal loctions) in subrequests
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /entry {
        echo_location /foo;
        echo_sleep 0.001;
        echo_location /foo2;
    }
  location /foo {
      echo_exec /baz;
  }
  location /foo2 {
      echo_exec /baz;
  }

  location /baz {
    proxy_pass http://127.0.0.1:$server_port/bar;
  }
  location /bar {
    echo_sleep 0.01;
    echo hello;
  }
--- request
    GET /entry
--- response_body
hello
hello



=== TEST 9: exec should clear ctx
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location @bar {
        echo hello;
        echo world;
        echo heh;
    }
  location /foo {
      #echo_sleep 0.001;
      echo_reset_timer;
      echo_exec @bar;
  }
--- request
    GET /foo
--- response_body
hello
world
heh



=== TEST 10: reset ctx
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location @proxy {
        rewrite_by_lua return;
        echo hello;
    }
    location /main {
        rewrite_by_lua return;
        echo_exec @proxy;
    }
--- request
    GET /main
--- response_body
hello
--- SKIP



=== TEST 11: yield before exec
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location @bar {
        echo hello;
        echo world;
        echo heh;
    }
  location /foo {
      echo_sleep 0.001;
      echo_exec @bar;
  }
--- request
    GET /foo
--- response_body
hello
world
heh

