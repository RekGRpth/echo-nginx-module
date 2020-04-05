# vi:filetype=

use lib 'lib';
use Test::Nginx::Socket;

repeat_each(2);

plan tests => repeat_each() * (2 * blocks() + 6) - 2;

#$Test::Nginx::LWP::LogLevel = 'debug';

run_tests();

__DATA__

=== TEST 1: sanity
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo hello;
    }
--- request
    GET /echo
--- response_body
hello



=== TEST 2: multiple args
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo say hello world;
    }
--- request
    GET /echo
--- response_body
say hello world



=== TEST 3: multiple directive instances
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo say that;
        echo hello;
        echo world !;
    }
--- request
    GET /echo
--- response_body
say that
hello
world !



=== TEST 4: echo without arguments
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo;
        echo;
    }
--- request
    GET /echo
--- response_body eval
"\n\n"



=== TEST 5: escaped newline
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo "hello\nworld";
    }
--- request
    GET /echo
--- response_body
hello
world



=== TEST 6: escaped tabs and \r and " wihtin "..."
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo "i say \"hello\tworld\"\r";
    }
--- request
    GET /echo
--- response_body eval: "i say \"hello\tworld\"\r\n"



=== TEST 7: escaped tabs and \r and " in single quotes
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo 'i say \"hello\tworld\"\r';
    }
--- request
    GET /echo
--- response_body eval: "i say \"hello\tworld\"\r\n"



=== TEST 8: escaped tabs and \r and " w/o any quotes
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo i say \"hello\tworld\"\r;
    }
--- request
    GET /echo
--- response_body eval: "i say \"hello\tworld\"\r\n"



=== TEST 9: escaping $
As of Nginx 0.8.20, there's still no way to escape the '$' character.
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo \$;
    }
--- request
    GET /echo
--- response_body
$
--- SKIP



=== TEST 10: XSS
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /blah {
        echo_duplicate 1 "$arg_callback(";
        echo_location_async "/data?$uri";
        echo_duplicate 1 ")";
    }
    location /data {
        echo_duplicate 1 '{"dog":"$query_string"}';
    }
--- request
    GET /blah/9999999.json?callback=ding1111111
--- response_body chomp
ding1111111({"dog":"/blah/9999999.json"})



=== TEST 11: XSS - filter version
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /blah {
        echo_before_body "$arg_callback(";

        echo_duplicate 1 '{"dog":"$uri"}';

        echo_after_body ")";
    }
--- request
    GET /blah/9999999.json?callback=ding1111111
--- response_body
ding1111111(
{"dog":"/blah/9999999.json"})



=== TEST 12: if
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
location /first {
 echo "before";
 echo_location_async /second $request_uri;
 echo "after";
}

location = /second {
 if ($query_string ~ '([^?]+)') {
     set $memcached_key $1;  # needing this to be keyed on the request_path, not the entire uri
     echo $memcached_key;
 }
}
--- request
    GET /first/9999999.json?callback=ding1111111
--- response_body
before
/first/9999999.json
after



=== TEST 13: echo -n
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo -n hello;
        echo -n world;
    }
--- request
    GET /echo
--- response_body chop
helloworld



=== TEST 14: echo a -n
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo a -n hello;
        echo b -n world;
    }
--- request
    GET /echo
--- response_body
a -n hello
b -n world



=== TEST 15: -n in a var
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        set $opt -n;
        echo $opt hello;
        echo $opt world;
    }
--- request
    GET /echo
--- response_body
-n hello
-n world



=== TEST 16: -n only
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo -n;
        echo -n;
    }
--- request
    GET /echo
--- response_body chop



=== TEST 17: -n with an empty string
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo -n "";
        set $empty "";
        echo -n $empty;
    }
--- request
    GET /echo
--- response_body chop



=== TEST 18: -- -n
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo -- -n hello;
        echo -- -n world;
    }
--- request
    GET /echo
--- response_body
-n hello
-n world



=== TEST 19: -n -n
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo -n -n hello;
        echo -n -n world;
    }
--- request
    GET /echo
--- response_body chop
helloworld



=== TEST 20: -n -- -n
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo -n -- -n hello;
        echo -n -- -n world;
    }
--- request
    GET /echo
--- response_body chop
-n hello-n world



=== TEST 21: proxy
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /main {
        proxy_pass http://127.0.0.1:$server_port/echo;
    }
    location /echo {
        echo hello;
        echo world;
    }
--- request
    GET /main
--- response_headers
!Content-Length
--- response_body
hello
world



=== TEST 22: if is evil
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /test {
        set $a 3;
        set_by_lua $a '
            if ngx.var.a == "3" then
                return 4
            end
        ';
        echo $a;
    }
--- request
    GET /test
--- response_body
4
--- SKIP



=== TEST 23: HEAD
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo hello;
        echo world;
    }
--- request
    HEAD /echo
--- response_body



=== TEST 24: POST
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo hello;
        echo world;
    }
--- pipelined_requests eval
["POST /echo
blah blah", "POST /echo
foo bar baz"]
--- response_body eval
["hello\nworld\n","hello\nworld\n"]



=== TEST 25: POST
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location /echo {
        echo_sleep 0.001;
        echo hello;
        echo world;
    }
--- pipelined_requests eval
["POST /echo
blah blah", "POST /echo
foo bar baz"]
--- response_body eval
["hello\nworld\n","hello\nworld\n"]



=== TEST 26: empty arg after -n (github issue #33)
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
--- config
    location = /t {
        set $empty "";
        echo -n $empty hello world;
    }
--- request
    GET /t
--- response_body chop
 hello world



=== TEST 27: image filter
--- main_config
    load_module /etc/nginx/modules/ngx_http_echo_module.so;
    load_module /etc/nginx/modules/ngx_http_image_filter_module.so;
--- config
    location = /gif {
        empty_gif;
    }

    location = /t {
        default_type image/gif;
        image_filter resize 10 10;
        set $gif1 '';
        set $gif2 '';
        rewrite_by_lua '
            local res = ngx.location.capture("/gif")
            local data = res.body
            ngx.var.gif1 = string.sub(data, 1, #data - 1)
            ngx.var.gif2 = string.sub(data, #data)
        ';
        echo -n $gif1;
        echo -n $gif2;
    }
--- request
    GET /t
--- stap
F(ngx_http_image_header_filter) {
    println("image header filter")
}
--- stap_out
image header filter
--- response_body_like: .
--- SKIP

