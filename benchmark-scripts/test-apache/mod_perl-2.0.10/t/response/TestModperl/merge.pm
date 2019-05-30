# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::merge;

use strict;
use warnings FATAL => 'all';

use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::RequestUtil ();
use APR::Table ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => 'OK';

# this is the configuration and handler for t/modperl/merge.t,
# t/modperl/merge2.t, and t/modperl/merge3.t.  see any of those
# tests and/or the below configuration for more details

# result tables for the below tests (trying to make the code more
# simple...) the hash itself represents a request
# the keys to the main hash represent merge levels - 1 for the
# non-overriding merge, 2 for an overriding merge, and 3 for a
# two-level merge the rest should be self-explanatory - settings and
# expected values.
our %merge1 = (
    1 => { PerlPassEnv => [APACHE_TEST_HOSTTYPE => 'z80'],
           PerlSetEnv  => [MergeSetEnv1 => 'SetEnv1Val'],
           PerlSetVar  => [MergeSetVar1 => 'SetVar1Val'],
           PerlAddVar  => [MergeAddVar1 => ['AddVar1Val1',
                                            'AddVar1Val2']],
         },
    2 => { PerlSetEnv  => [MergeSetEnv2 => 'SetEnv2Val'],
           PerlSetVar  => [MergeSetVar2 => 'SetVar2Val'],
           PerlAddVar  => [MergeAddVar2 => ['AddVar2Val1',
                                            'AddVar2Val2']],
         },
    3 => { PerlSetEnv  => [MergeSetEnv3 => 'SetEnv3Val'],
           PerlSetVar  => [MergeSetVar3 => 'SetVar3Val'],
           PerlAddVar  => [MergeAddVar3 => ['AddVar3Val1',
                                            'AddVar3Val2']],
         },
);

our %merge2 = (
    1 => { PerlPassEnv => [APACHE_TEST_HOSTTYPE => 'z80'],
           PerlSetEnv  => [MergeSetEnv1 => 'SetEnv1Val'],
           PerlSetVar  => [MergeSetVar1 => 'SetVar1Val'],
           PerlAddVar  => [MergeAddVar1 => ['AddVar1Val1',
                                            'AddVar1Val2']],
         },
    2 => { PerlSetEnv  => [MergeSetEnv2 => 'SetEnv2Merge2Val'],
           PerlSetVar  => [MergeSetVar2 => 'SetVar2Merge2Val'],
           PerlAddVar  => [MergeAddVar2 => ['AddVar2Merge2Val1',
                                            'AddVar2Merge2Val2']],
         },
    3 => { PerlSetEnv  => [MergeSetEnv3 => 'SetEnv3Val'],
           PerlSetVar  => [MergeSetVar3 => 'SetVar3Val'],
           PerlAddVar  => [MergeAddVar3 => ['AddVar3Val1',
                                            'AddVar3Val2']],
         },
);

our %merge3 = (
    1 => { PerlPassEnv => [APACHE_TEST_HOSTTYPE => 'z80'],
           PerlSetEnv  => [MergeSetEnv1 => 'SetEnv1Val'],
           PerlSetVar  => [MergeSetVar1 => 'SetVar1Val'],
           PerlAddVar  => [MergeAddVar1 => ['AddVar1Val1',
                                            'AddVar1Val2']],
         },
    2 => { PerlSetEnv  => [MergeSetEnv2 => 'SetEnv2Merge3Val'],
           PerlSetVar  => [MergeSetVar2 => 'SetVar2Merge3Val'],
           PerlAddVar  => [MergeAddVar2 => ['AddVar2Merge3Val1',
                                            'AddVar2Merge3Val2']],
         },
    3 => { PerlSetEnv  => [MergeSetEnv3 => 'SetEnv3Merge3Val'],
           PerlSetVar  => [MergeSetVar3 => 'SetVar3Merge3Val'],
           PerlAddVar  => [MergeAddVar3 => ['AddVar3Merge3Val1',
                                            'AddVar3Merge3Val2']],
         },
);

sub handler {
    my $r = shift;

    plan $r, tests => 10;

    my $uri = $r->uri;
    my $hash;

    if ($uri =~ m/(merge3)/) {
        $hash = $1;
    } elsif ($uri =~ m/(merge2)/) {
        $hash = $1;
    } else {
        $hash = 'merge1';
    }

    t_debug("testing against results in $hash");

    no strict qw(refs);
    foreach my $level (sort keys %$hash) {
        foreach my $directive (sort keys %{ $hash->{$level} }) {
            my $key   = $hash->{$level}->{$directive}->[0];
            my $value = $hash->{$level}->{$directive}->[1];

            my @expected = ref $value ? @$value : $value;

            my $comment = join ' ', $directive, $key, @expected;

            if ($directive =~ m/Env/) {
                my $received = $ENV{$key};
                ok t_cmp($received, $expected[0], $comment);
            }
            elsif ($directive =~ m/Set/) {
                my $received = $r->dir_config->get($key);
                ok t_cmp($received, $expected[0], $comment);
            }
            else {
                my @received = $r->dir_config->get($key);
                ok t_cmp(\@received, \@expected, $comment);
            }
        }
    }

    Apache2::Const::OK;
}

1;
__END__
<NoAutoConfig>
    PerlModule TestModperl::merge

    <VirtualHost TestModperl::merge>
        # these should pass through all merges untouched
        PerlPassEnv  APACHE_TEST_HOSTTYPE
        PerlSetEnv   MergeSetEnv1  SetEnv1Val
        PerlSetVar   MergeSetVar1  SetVar1Val
        PerlSetVar   MergeAddVar1  AddVar1Val1
        PerlAddVar   MergeAddVar1  AddVar1Val2

        # these are overridden in /merge2 and /merge3
        PerlSetEnv   MergeSetEnv2  SetEnv2Val
        PerlSetVar   MergeSetVar2  SetVar2Val
        PerlSetVar   MergeAddVar2  AddVar2Val1
        PerlAddVar   MergeAddVar2  AddVar2Val2

        # these are overridden in /merge3 only
        PerlSetEnv   MergeSetEnv3  SetEnv3Val
        PerlSetVar   MergeSetVar3  SetVar3Val
        PerlSetVar   MergeAddVar3  AddVar3Val1
        PerlAddVar   MergeAddVar3  AddVar3Val2

        <Location /merge>
            # same as per-server level
            SetHandler perl-script
            PerlResponseHandler TestModperl::merge
        </Location>

        <Location /merge2>
            # overrides "2" values - "1" and "3" values left untouched
            PerlSetEnv   MergeSetEnv2  SetEnv2Merge2Val
            PerlSetVar   MergeSetVar2  SetVar2Merge2Val
            PerlSetVar   MergeAddVar2  AddVar2Merge2Val1
            PerlAddVar   MergeAddVar2  AddVar2Merge2Val2

            SetHandler perl-script
            PerlResponseHandler TestModperl::merge
        </Location>

        AccessFileName htaccess
        <Directory @DocumentRoot@/merge3>
            # overrides "2" values
            PerlSetEnv   MergeSetEnv2  SetEnv2Merge3Val
            PerlSetVar   MergeSetVar2  SetVar2Merge3Val
            PerlSetVar   MergeAddVar2  AddVar2Merge3Val1
            PerlAddVar   MergeAddVar2  AddVar2Merge3Val2

            SetHandler perl-script
            PerlResponseHandler TestModperl::merge

            # override "3" values
            AllowOverride all
        </Directory>

    </VirtualHost>
</NoAutoConfig>
