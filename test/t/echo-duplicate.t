# vi:filetype=perl

use lib 'lib';
use Test::Nginx::Echo;

plan tests => 1 * blocks();

#$Test::Nginx::Echo::LogLevel = 'debug';

run_tests();

__DATA__

=== TEST 1: sanity
--- config
    location /dup {
        echo_duplicate 3 a;
    }
--- request
    GET /dup
--- response_body: aaa



=== TEST 2: abc abc
--- config
    location /dup {
        echo_duplicate 2 abc;
    }
--- request
    GET /dup
--- response_body: abcabc



=== TEST 3: big size with underscores
--- config
    location /dup {
        echo_duplicate 10_000 A;
    }
--- request
    GET /dup
--- response_body eval
'A' x 10_000
