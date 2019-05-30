# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_init_basic;

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
sub init : FilterInitHandler {
    my $filter = shift;

    #warn "**** init was invoked\n";

    my $ctx = $filter->ctx;
    $ctx->{init}++;
    $filter->r->notes->set(init => $ctx->{init});
    $filter->ctx($ctx);

    #warn "**** init is exiting\n";

    return Apache2::Const::OK;
}

# testing whether we can get the pre handler callback in evolved way
sub get_pre_handler { return \&TestFilter::out_init_basic::init }

# this filter adds a count for each time it is invoked
sub transparent : FilterRequestHandler
                  FilterHasInitHandler(get_pre_handler())
    {
    my ($filter, $bb) = @_;

    #warn "**** filter was invoked\n";

    my $ctx = $filter->ctx;

    $filter->print('run ', ++$ctx->{run}, "\n");

    $filter->ctx($ctx);

    my $rv = $filter->next->pass_brigade($bb);
    return $rv unless $rv == APR::Const::SUCCESS;

    #warn "**** filter is exiting\n";

    return Apache2::Const::OK;
}

sub response {
    my $r = shift;

    #warn "**** content was invoked\n";

    $r->content_type('text/plain');

    my $data;
    if ($r->method_number == Apache2::Const::M_POST) {
        $data = TestCommon::Utils::read_post($r);
    }

    $r->print('init ', $r->notes->get('init'), "\n");
    $r->print($data) if $data;

    #warn "**** content is exiting\n";

    Apache2::Const::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule             TestFilter::out_init_basic
PerlResponseHandler    TestFilter::out_init_basic::response
PerlOutputFilterHandler TestFilter::out_init_basic::transparent
