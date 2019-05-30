# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::cleanup2;

# test the cleanup handler removing a temp file

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use File::Spec::Functions qw(catfile);

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use APR::Pool ();

use Apache2::Const -compile => qw(OK DECLINED);
use APR::Const    -compile => 'SUCCESS';

my $file = catfile Apache::Test::config->{vars}->{documentroot},
    "hooks", "cleanup2";

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    t_write_file($file, "cleanup2 is ok");

    my $status = $r->sendfile($file);
    die "sendfile has failed" unless $status == APR::Const::SUCCESS;

    $r->pool->cleanup_register(\&cleanup, $file);

    return Apache2::Const::OK;
}

sub cleanup {
    my $file_arg = shift;

    debug_sub "called";
    die "Can't find file: $file_arg" unless -e $file_arg;
    unlink $file_arg or die "failed to unlink $file_arg";

    return Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
  <Location /TestHooks__cleanup2>
      SetHandler modperl
      PerlResponseHandler TestHooks::cleanup2
  </Location>
</NoAutoConfig>
