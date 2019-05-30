# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use File::Spec::Functions qw(catfile);

use Apache2::Const -compile => qw(FORBIDDEN);

my $module   = 'TestAPI::custom_response';
my $location = '/' . Apache::TestRequest::module2path($module);

my $config   = Apache::Test::config();
my $hostport = Apache::TestRequest::hostport($config);
t_debug("connecting to $hostport");

my $file = catfile Apache::Test::vars('documentroot'),
    qw(api custom_response.txt);

open my $fh, $file or die "Can't open $file: $!";
my $data = do { binmode $fh; local $/; <$fh> };
close $fh;

plan tests => 4, need need_lwp, 'HTML::HeadParser';

{
    # custom text response
    my $expected = "This_is_a_custom_text_response";
    my $res = GET "$location?$expected";
    ok t_cmp $res->code, Apache2::Const::FORBIDDEN, "custom text response (code)";
    ok t_cmp $res->content, $expected, "custom text response (body)";
}

{
    # custom relative url response
    my $url = "/api/custom_response.txt";
    my $res = GET "$location?$url";
    ok t_cmp $res->content, $data, "custom file response (body)";
}
{
    my $url = "http://$hostport/api/custom_response.txt";
    # custom full url response
    my $res = GET "$location?$url";
    ok t_cmp $res->content, $data, "custom file response (body)";
}

