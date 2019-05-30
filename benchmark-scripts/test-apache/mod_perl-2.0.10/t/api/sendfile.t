# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use File::Spec::Functions qw(catfile);

my $url = '/TestAPI__sendfile';

my $file = catfile Apache::Test::vars('serverroot'),
    'response/TestAPI/sendfile.pm';

my $contents;
open my $fh, $file or die "can't open $file: $!";
# need binmode on Win32 so as not to strip \r, which
# are included when sending with sendfile().
binmode $fh;
{ local $/; $contents = <$fh>; }
close $fh;

plan tests => 7, need 'HTML::HeadParser';

{
    my $header = "This is a header\n";
    my $footer = "This is a footer\n";

    my $received = GET_BODY "$url?withwrapper";
    my $expected = join '', $header, $contents, $footer;
    #t_debug($received);
    ok $received && $received eq $expected;
}

{
    my $received = GET_BODY "$url?offset";
    my $expected = substr $contents, 3;
    #t_debug($received);
    ok $received && $received eq $expected;
}

{
    my $received = GET_BODY "$url?len";
    my $expected = substr $contents, 3, 50;
    #t_debug($received);
    ok $received && $received eq $expected;
}

{
    # rc is checked and handled by the code
    my $res = GET "$url?noexist.txt";
    ok t_cmp($res->code, 500, "failed sendfile");
    #t_debug($res->content);
    ok $res->content =~ /an internal error/;
}

{
    # rc is not checked in this one, testing the exception throwing
    my $res = GET "$url?noexist-n-nocheck.txt";
    ok t_cmp($res->code, 500, "failed sendfile");
    #t_debug($res->content);
    ok $res->content =~ /an internal error/;
}
