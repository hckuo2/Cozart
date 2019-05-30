# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::local_env;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => 'OK';

# local %ENV used to cause segfaults
# Report: http://thread.gmane.org/gmane.comp.apache.mod-perl/22236
# Fixed in: http://svn.apache.org/viewcvs.cgi?rev=357236&view=rev
sub handler {
    my $r = shift;

    plan $r, tests => 6;

    my %copy_ENV = %ENV;  ## this is not a deep copy;

    ok t_cmp($ENV{MOD_PERL_API_VERSION}, 2,
      "\$ENV{MOD_PERL_API_VERSION} is 2 before local \%ENV");

    {
      local %ENV;

      ok t_cmp($ENV{MOD_PERL_API_VERSION}, undef,
          "\$ENV{MOD_PERL_API_VERSION} is undef after local \%ENV");

      ok t_cmp(scalar keys %ENV, 0,
          "\%ENV has 0 keys after local");

      $ENV{LOCAL} = 1;

      ok t_cmp($ENV{LOCAL}, 1,
          "can set value after local, but still in block");
    }

    ok t_cmp($ENV{LOCAL}, undef,
      "valuee set in local {} block is gone after leaving scope");

    ok t_cmp(\%copy_ENV, \%ENV, "\%ENV was restored correctly");

    Apache2::Const::OK;
}

1;
__END__
SetHandler perl-script
