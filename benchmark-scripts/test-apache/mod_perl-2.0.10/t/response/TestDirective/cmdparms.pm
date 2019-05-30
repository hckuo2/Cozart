# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestDirective::cmdparms;

use strict;
use warnings FATAL => 'all';

use Apache2::CmdParms ();
use Apache2::Directive ();
use base qw(Apache2::Module);

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(
    ACCESS_CONF
    M_GET
    M_POST
    M_PUT
    M_DELETE
    OK
    OR_AUTHCFG
    OR_FILEINFO
    OR_INDEXES
    OR_LIMIT
    OR_OPTIONS
    RSRC_CONF
    NOT_IN_LOCATION
);

use constant KEY => "TestCmdParms";

my @directives = (
    {
        name        => +KEY,
        cmd_data    => 'cmd_data',
        errmsg      => 'errmsg',
    },
);

Apache2::Module::add(__PACKAGE__, \@directives);

my @methods = qw(cmd context directive info override path
                 pool server temp_pool);

sub TestCmdParms {
    my ($self, $parms, $args) = @_;
    my $srv_cfg = $self->get_config($parms->server);
    foreach my $method (@methods) {
        $srv_cfg->{$args}{$method} = $parms->$method();
    }
    $srv_cfg->{$args}{check_ctx} =
        $parms->check_cmd_context(Apache2::Const::NOT_IN_LOCATION);

    $srv_cfg->{$args}{limited} = $parms->method_is_limited('GET');

    my $directive = $parms->directive;
    $srv_cfg->{$args}{line_num} = $directive->line_num;
    $srv_cfg->{$args}{filename} = $directive->filename;
}

### response handler ###
sub handler : method {
    my ($self, $r) = @_;
    my $override;
    my $srv_cfg = $self->get_config($r->server);

    plan $r, tests => 11 + ( 7 * keys(%$srv_cfg) );

    foreach my $cfg (values %$srv_cfg) {
        ok t_cmp(ref($cfg->{cmd}), 'Apache2::Command', 'cmd');
        ok t_cmp(ref($cfg->{context}), 'Apache2::ConfVector', 'context');
        ok t_cmp(ref($cfg->{directive}), 'Apache2::Directive', 'directive');
        ok t_cmp(ref($cfg->{pool}), 'APR::Pool', 'pool');
        ok t_cmp(ref($cfg->{temp_pool}), 'APR::Pool', 'temp_pool');
        ok t_cmp(ref($cfg->{server}), 'Apache2::ServerRec', 'server');
        ok t_cmp($cfg->{info}, 'cmd_data', 'cmd_data');
    }

    # vhost
    {
        my $vhost = $srv_cfg->{Vhost};

        my $wanted = Apache2::Const::RSRC_CONF   |
                     Apache2::Const::OR_INDEXES  |
                     Apache2::Const::OR_FILEINFO |
                     Apache2::Const::OR_OPTIONS;
        my $masked = $vhost->{override} & $wanted;

        ok t_cmp($masked, $wanted, 'override bitmask');
        ok t_cmp($vhost->{path}, undef, 'path');
        ok t_cmp($vhost->{check_ctx}, undef, 'check_cmd_ctx');
        ok $vhost->{limited};

        ok t_cmp $vhost->{filename}, qr|httpd.conf$|, "config filename";
        ok t_cmp $vhost->{line_num}, qr|^\d+$|, "config filename line_num";
    }

    # Location
    {
        my $loc = $srv_cfg->{Location};

        my $wanted = Apache2::Const::ACCESS_CONF |
                     Apache2::Const::OR_INDEXES  |
                     Apache2::Const::OR_AUTHCFG  |
                     Apache2::Const::OR_FILEINFO |
                     Apache2::Const::OR_OPTIONS  |
                     Apache2::Const::OR_LIMIT;
        my $masked = $loc->{override} & $wanted;

        ok t_cmp($masked, $wanted, 'override bitmask');
        ok t_cmp($loc->{path}, '/TestDirective__cmdparms', 'path');
        ok t_cmp($loc->{check_ctx}, KEY .
                  ' cannot occur within <Location> section', 'check_cmd_ctx');
        ok $loc->{limited};
    }

    # Limit
    {
        my $limit = $srv_cfg->{Limit};
        ok !$limit->{limited};
    }

    return Apache2::Const::OK;
}

1;
__END__

# APACHE_TEST_CONFIG_ORDER 950

<Base>
PerlLoadModule TestDirective::cmdparms
TestCmdParms "Vhost"
</Base>

TestCmdParms "Location"
#FIXME! httpd 2.4 does not allow LimitExcept here
#<LimitExcept GET>
    #TestCmdParms "Limit"
#</LimitExcept>
