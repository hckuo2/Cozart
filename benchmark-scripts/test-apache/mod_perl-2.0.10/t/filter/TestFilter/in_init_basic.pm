# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::in_init_basic;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use base qw(Apache2::Filter);

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK M_POST);

use constant READ_SIZE  => 1024;

# this filter is expected to be called once
# it'll set a note, with the count
sub transparent_init : FilterInitHandler {
    my $filter = shift;

    my $ctx = $filter->ctx;
    $ctx->{init}++;
    $filter->r->notes->set(init => $ctx->{init});
    $filter->ctx($ctx);

    return Apache2::Const::OK;
}

# this filter passes the data through unmodified and sets a note
# counting how many times it was invoked
sub transparent : FilterRequestHandler
                  FilterHasInitHandler(\&transparent_init)
    {
    my ($filter, $bb, $mode, $block, $readbytes) = @_;

    my $ctx = $filter->ctx;
    $ctx->{run}++;
    $filter->r->notes->set(run => $ctx->{run});
    $filter->ctx($ctx);

    $filter->next->get_brigade($bb, $mode, $block, $readbytes);

    return Apache2::Const::OK;
}



# this filter is not supposed to get a chance to run, since its init
# handler immediately removes it
sub suicide_init : FilterInitHandler { shift->remove(); Apache2::Const::OK }
sub suicide      : FilterHasInitHandler(\&suicide_init) {
    die "this filter is not supposed to have a chance to run";
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    if ($r->method_number == Apache2::Const::M_POST) {
        $r->print(TestCommon::Utils::read_post($r));
    }

    my @keys = qw(init run);
    my %times = map { $_ => $r->notes->get($_)||0 } @keys;
    $r->print("$_ $times{$_}\n") for @keys;

    Apache2::Const::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule             TestFilter::in_init_basic
PerlResponseHandler    TestFilter::in_init_basic::response
PerlInputFilterHandler TestFilter::in_init_basic::suicide
PerlInputFilterHandler TestFilter::in_init_basic::transparent
