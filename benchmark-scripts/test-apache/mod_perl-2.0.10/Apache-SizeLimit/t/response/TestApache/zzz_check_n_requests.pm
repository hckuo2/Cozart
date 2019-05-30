package TestApache::zzz_check_n_requests;

use strict;
use warnings;

use Apache::Constants;

use Apache::Test qw(-withtestmore);
use Apache::TestUtil;

use Apache::SizeLimit;

use constant ONE_MB    => 1024;
use constant TEN_MB    => ONE_MB * 10;
use constant TWENTY_MB => TEN_MB * 2;

my $i = 0;
my %hash = ();

sub handler {
    my $r = shift;

    plan $r, tests => 11;

    Apache::SizeLimit->add_cleanup_handler($r);
    Apache::SizeLimit->set_max_process_size(TEN_MB);
    ## this should cause us to fire
    Apache::SizeLimit->set_check_interval();

    # We can assume this will use _at least_ 1MB of memory, based on
    # assuming a scalar consumes >= 1K.
    # and after 10 requests, we should be _at least_ 10MB of memory
    for (0..9) {
        my @big = ('x') x ONE_MB;
        $hash{$i++} = \@big;
        is(
           $i,
           $i,
           "now using $i MB of memory (at least)"
          );
    }

    is(
       1,
       Apache::SizeLimit->_limits_are_exceeded(),
       "we passed the limits and _WILL_ kill the child"
      );

    return Apache::Constants::OK;
}

1;
