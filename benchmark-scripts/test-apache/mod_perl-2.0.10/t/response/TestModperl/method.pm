# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::method;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

use Apache2::Const -compile => 'OK';

sub new {
    my $class = shift;

    bless {
        perl_version => $],
    }, $class;
}

sub handler : method {
    my ($self, $r) = @_;

    my $tests = 3;

    my $is_obj = ref($self);

    if ($is_obj) {
        $tests += 1;
    }

    plan $r, tests => $tests;

    ok t_cmp(scalar @_, 2,
             '@_ == 2');

    my $class = ref($self) || $self;

    ok t_cmp($class, $class,
             'handler class');

    ok t_cmp(
        $r->uri,
        '/' . Apache::TestRequest::module2path($class),
        '$r->uri eq $location');

    if ($is_obj) {
        ok t_cmp($self->{perl_version}, $],
                 'object handler data');
    }

    Apache2::Const::OK;
}

1;
__END__
