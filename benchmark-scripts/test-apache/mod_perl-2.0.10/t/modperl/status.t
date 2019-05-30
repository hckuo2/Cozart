# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestRequest;
use Apache::TestUtil qw(t_cmp t_server_log_error_is_expected);

use Apache2::Const -compile => qw(OK DECLINED
                                 NOT_FOUND SERVER_ERROR FORBIDDEN
                                 HTTP_OK);

plan tests => 15, need 'HTML::HeadParser';

my $base = "/TestModperl__status";

# valid Apache return codes
{
    my $uri = join '?', $base, Apache2::Const::OK;
    my $code = GET_RC $uri;

    ok t_cmp($code,
             Apache2::Const::HTTP_OK,
             $uri);
}

{
    my $uri = join '?', $base, Apache2::Const::DECLINED;
    my $code = GET_RC $uri;

    # no Alias to map us to DocumentRoot
    ok t_cmp($code,
             Apache2::Const::NOT_FOUND,
             $uri);
}

# standard HTTP status codes
{
    my $uri = join '?', $base, Apache2::Const::NOT_FOUND;
    my $code = GET_RC $uri;

    ok t_cmp($code,
             Apache2::Const::NOT_FOUND,
             $uri);
}

{
    my $uri = join '?', $base, Apache2::Const::FORBIDDEN;
    my $code = GET_RC $uri;

    ok t_cmp($code,
             Apache2::Const::FORBIDDEN,
             $uri);
}

{
    my $uri = join '?', $base, Apache2::Const::SERVER_ERROR;
    my $code = GET_RC $uri;

    ok t_cmp($code,
             Apache2::Const::SERVER_ERROR,
             $uri);
}

# apache translates non-HTTP codes into 500
# see ap_index_of_response
{
    my $uri = join '?', $base, 601;
    my $code = GET_RC $uri;

    ok t_cmp($code,
             Apache2::Const::SERVER_ERROR,
             $uri);
}

{
    my $uri = join '?', $base, 313;
    my $code = GET_RC $uri;

    ok t_cmp($code,
             Apache2::Const::SERVER_ERROR,
             $uri);
}

{
    my $uri = join '?', $base, 1;
    my $code = GET_RC $uri;

    ok t_cmp($code,
             Apache2::Const::SERVER_ERROR,
             $uri);
}

# HTTP_OK is treated as an error, since it's not
# OK, DECLINED, or DONE.  while apache's lookups
# succeed so the 200 is propagated to the client,
# there's an error beneath that 200 code.
{
    my $uri = join '?', $base, Apache2::Const::HTTP_OK;
    my $response = GET $uri;

    ok t_cmp($response->code,
             Apache2::Const::HTTP_OK,
             $uri);

    ok t_cmp($response->content,
             qr/server encountered an internal error/,
             $uri);
}

# mod_perl-specific implementation tests
{
    # ModPerl::Util::exit - voids return OK
    my $uri = join '?', $base, 'exit';
    my $code = GET_RC $uri;

    ok t_cmp($code,
             Apache2::Const::HTTP_OK,
             $uri);
}

{
    # die gets trapped
    my $uri = join '?', $base, 'die';
    my $code = GET_RC $uri;

    ok t_cmp($code,
             Apache2::Const::SERVER_ERROR,
             $uri);
}

{
    my $uri = join '?', $base, 'foobar';
    my $code = GET_RC $uri;

    ok t_cmp($code,
             Apache2::Const::HTTP_OK,
             $uri);
}

{
    my $uri = join '?', $base, 'foo9bar';
    my $code = GET_RC $uri;

    ok t_cmp($code,
             Apache2::Const::HTTP_OK,
             $uri);
}

{
    my $uri = join '?', $base, 'undef';
    my $code = GET_RC $uri;

    ok t_cmp($code,
             Apache2::Const::HTTP_OK,
             $uri);
}

