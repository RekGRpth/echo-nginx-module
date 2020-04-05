# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

plan tests => 2 * blocks();

run_tests();

__DATA__

=== TEST 1: sanity
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo_sleep 1;
    }
--- request
    GET /echo
--- response_body



=== TEST 2: fractional delay
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo_sleep 0.01;
    }
--- request
    GET /echo
--- response_body



=== TEST 3: leading echo
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo before...;
        echo_sleep 0.01;
    }
--- request
    GET /echo
--- response_body
before...



=== TEST 4: trailing echo
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo_sleep 0.01;
        echo after...;
    }
--- request
    GET /echo
--- response_body
after...



=== TEST 5: two echos around sleep
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo before...;
        echo_sleep 0.01;
        echo after...;
    }
--- request
    GET /echo
--- response_body
before...
after...



=== TEST 6: interleaving sleep and echo
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo 1;
        echo_sleep 0.01;
        echo 2;
        echo_sleep 0.01;
    }
--- request
    GET /echo
--- response_body
1
2



=== TEST 7: interleaving sleep and echo with echo at the end...
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo 1;
        echo_sleep 0.01;
        echo 2;
        echo_sleep 0.01;
        echo 3;
    }
--- request
    GET /echo
--- response_body
1
2
3



=== TEST 8: flush before sleep
we didn't really test the actual effect of "echo_flush" here...
merely checks if it croaks if appears.
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /flush {
        echo hi;
        echo_flush;
        echo_sleep 0.01;
        echo trees;
    }
--- request
    GET /flush
--- response_body
hi
trees



=== TEST 9: flush does not increment opcode pointer itself
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /flush {
        echo hi;
        echo_flush;
        echo trees;
    }
--- request
    GET /flush
--- response_body
hi
trees



=== TEST 10: sleep through a proxy
this reveals a bug in v0.19 and the bug is fixed in v0.20.
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /proxy {
        proxy_pass $scheme://127.0.0.1:$server_port/entry';
    }
    location /entry {
        echo_sleep 0.001;
        echo done;
    }
--- request
    GET /proxy
--- response_body_like
done



=== TEST 11: abnormally quit
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /quit {
        echo before;
        echo_flush;
        echo_sleep 1;
        echo after;
    }
--- request
    GET /quit
--- response_body
before
after



=== TEST 12: two echos around sleep (HEAD)
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo before...;
        echo_sleep 0.01;
        echo after...;
    }
--- request
    HEAD /echo
--- response_body



=== TEST 13: sleep by variable
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location ~ ^/sleep/(.+) {
        echo before...;
        echo_sleep $1;
        echo after...;
    }
--- request
    GET /sleep/0.01
--- response_body
before...
after...

