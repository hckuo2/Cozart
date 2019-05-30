# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;

use Apache::TestUtil;
use Apache::TestRequest;

plan tests => 5;

my $location = "/TestCompat__request_body";

# $r->send_http_header('text/plain');
{
    my @data = (test => 'content-type');
    ok t_cmp(
        HEAD(query(@data))->content_type(),
        "text/plain",
        q{$r->send_http_header('text/plain')}
        );
}

# $r->content
{
    my @data = (test => 'content');
    my $content = join '=', @data;
    ok t_cmp(
        POST_BODY($location, content => $content),
        "@data",
        q{$r->content via POST}
        );
}

# $r->Apache2::args
{
    my @data = (test => 'args');
    ok t_cmp(
        GET_BODY(query(@data)),
        "@data",
        q{$r->Apache2::args}
        );
}

# encoding/decoding
{
    my %data = (
        test => 'decoding',
        body => '%DC%DC+%EC%2E+%D6%D6+%D6%2F',
    );
    ok t_cmp(
        GET_BODY(query(%data)),
        $data{body},
        q{decoding}
       );
}


# big POST
{
    my %data = (
        test => 'big_input',
        body => ('x' x 819_235),
       );
    my $content = join '=', %data;
    ok t_cmp(
        POST_BODY($location, content => $content),
        length($data{body}),
        q{big POST}
       );
}



### helper subs ###
sub query {
    my (%args) = (@_ % 2) ? %{+shift} : @_;
    "$location?" . join '&', map { "$_=$args{$_}" } keys %args;
}

