# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::request_subclass;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestUtil ();
our @ISA = qw(Apache2::RequestRec);

use Apache::Test;
use Apache::TestRequest;

use Apache2::Const -compile => 'OK';

sub new {
    my $class = shift;
    my $r = shift;
    bless { r => $r }, $class;
}

my $location = '/' . Apache::TestRequest::module2path(__PACKAGE__);

sub handler {
    my $r = __PACKAGE__->new(shift);

    plan $r, tests => 5;

    eval { my $gr = Apache2::RequestUtil->request; };
    ok $@;

    ok $r->uri eq $location;

    ok ((bless { r => $r })->uri eq $location); #nested

    eval { (bless {})->uri };

    ok $@ =~ /no .* key/;

    eval { (bless [])->uri };

    ok $@ =~ /unsupported/;

    Apache2::Const::OK;
}

1;
__END__
SetHandler perl-script
PerlOptions -GlobalRequest
