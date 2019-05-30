# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::in_str_msg;

# test:
# - input connection filter rewriting the first HTTP header POST
# - input request filter configured outside the resource container
#   should work just fine (via PerlOptions +MergeHandlers)
# - input connection filter configured inside the resource container
#   is silently skipped (at the moment we can't complain about such,
#   since there could be connection filters from outside the resource
#   container that will get merged inside the resource dir_config

use strict;
use warnings FATAL => 'all';

use base qw(Apache2::Filter);

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use APR::Brigade ();
use APR::Bucket ();

use Apache::Test;
use Apache::TestUtil;

use TestCommon::Utils ();

use Apache2::Const -compile => 'OK';
use APR::Const -compile => ':common';

my $from_url = '/input_filter.html';
my $to_url = '/TestFilter__in_str_msg';

sub con : FilterConnectionHandler {
    my $filter = shift;

    #warn "FILTER con CALLED\n";
    my $ctx = $filter->ctx;

    while ($filter->read(my $buffer, 1024)) {
        #warn "FILTER READ: $buffer\n";
        unless ($ctx) {
            $buffer =~ s|POST $from_url|POST $to_url|;
            $ctx = 1; # done
        }
        $filter->print($buffer);
    }
    $filter->ctx($ctx) if $ctx;

    return Apache2::Const::OK;
}

sub req : FilterRequestHandler {
    my $filter = shift;

    #warn "FILTER req CALLED\n";
    while ($filter->read(my $buffer, 1024)) {
        $buffer =~ s/upcase me/UPCASED/;
        $filter->print($buffer);
    }

    return Apache2::Const::OK;
}

sub con_skip : FilterConnectionHandler {
    my $filter = shift;

    #warn "FILTER con_skip CALLED\n";
    while ($filter->read(my $buffer, 1024)) {
        $filter->print("I'm a bogus filter. Don't run me\n");
    }

    return Apache2::Const::OK;
}

my $expected = "UPCASED";
sub response {
    my $r = shift;

    plan $r, tests => 1;

    my $received = TestCommon::Utils::read_post($r);

    ok t_cmp($received, $expected,
             "request filter must have upcased the data");

    Apache2::Const::OK;
}

1;
__END__
<NoAutoConfig>
<VirtualHost TestFilter::in_str_msg>
  PerlModule TestFilter::in_str_msg
  PerlInputFilterHandler TestFilter::in_str_msg::con

  # this request filter is outside the resource container and it
  # should work just fine because of PerlOptions +MergeHandlers
  PerlInputFilterHandler TestFilter::in_str_msg::req

  <Location /TestFilter__in_str_msg>
     SetHandler modperl
     PerlOptions +MergeHandlers
     PerlInputFilterHandler TestFilter::in_str_msg::con_skip
     PerlResponseHandler TestFilter::in_str_msg::response
  </Location>

</VirtualHost>
</NoAutoConfig>
