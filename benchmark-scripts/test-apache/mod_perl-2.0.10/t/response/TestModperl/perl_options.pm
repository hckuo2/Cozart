# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModperl::perl_options;

# test whether PerlOptions options are enabled

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::ServerUtil ();

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(OK);

my @srv_plus  = qw(ChildInit ChildExit Fixup);
my @srv_minus = qw(PreConnection ProcessConnection Autoload
                   Log InputFilter OutputFilter);
my @dir_plus  = qw(ParseHeaders MergeHandlers);
my @dir_minus = qw(SetupEnv GlobalRequest);

sub handler {
    my $r = shift;

    plan $r, tests => @srv_plus + @srv_minus + @dir_plus + @dir_minus;
    my $s = $r->server;

    ok t_cmp($s->is_perl_option_enabled($_), 1,
             "PerlOptions +$_") for @srv_plus;

    ok t_cmp($s->is_perl_option_enabled($_), 0,
             "PerlOptions -$_") for @srv_minus;

    ok t_cmp($r->is_perl_option_enabled($_), 1,
             "PerlOptions +$_") for @dir_plus;

    ok t_cmp($r->is_perl_option_enabled($_), 0,
             "PerlOptions -$_") for @dir_minus;

    return Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
<VirtualHost TestModperl::perl_options>
    PerlOptions -PreConnection -ProcessConnection
    PerlOptions -Autoload -Log -InputFilter -OutputFilter
    PerlOptions +ChildInit +ChildExit
    PerlModule TestModperl::perl_options
    PerlOptions +ParseHeaders
    <Location /TestModperl__perl_options>
        SetHandler modperl
        PerlOptions -GlobalRequest -SetupEnv
        PerlOptions +MergeHandlers
        PerlResponseHandler TestModperl::perl_options
    </Location>
</VirtualHost>
</NoAutoConfig>

