# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::add_config;

use strict;
use warnings FATAL => 'all';

use Apache2::Access ();
use Apache2::CmdParms ();
use Apache2::RequestUtil ();
use Apache2::Directive ();
use Apache2::ServerUtil ();
use base qw(Apache2::Module);

use Apache::Test;
use Apache::TestUtil;

use Apache2::Const -compile => qw(
    OK
    DECLINED
    :options
);

use constant KEY        => "TestAddConfig";
use constant APACHE22   => have_min_apache_version('2.2.0');
use constant APACHE24   => have_min_apache_version('2.4.0');

my @directives = (
    {
        name        => KEY,
        cmd_data    => 'cmd_data',
        errmsg      => 'errmsg',
    },
);

Apache2::Module::add(__PACKAGE__, \@directives);

sub TestAddConfig {
    my ($self, $parms, $args) = @_;
    my $srv_cfg = $self->get_config($parms->server);
    $srv_cfg->{override_opts} = $parms->override_opts();
}

sub map2storage {
    my $r = shift;

    my $o = APACHE22 ? '=All,SymLinksIfOwnerMatch' : '';

    eval {
        $r->add_config(['AllowOverride All Options'.$o]);
    };
    $r->pnotes(add_config1 => "$@");

    eval {
        $r->add_config(['Options ExecCGI'], -1, '/', 0);
    };
    $r->pnotes(add_config2 => "$@");

    # We can set AllowOverride only from .htacces in 2.4.0+
    if (!APACHE24) {
        eval {
            $r->add_config(['AllowOverride Options=FollowSymLinks'], -1);
        };
        $r->pnotes(followsymlinks => "$@");
    }

    eval {
        my $path="/a/path/to/somewhere";
        $r->add_config(['PerlResponseHandler '.__PACKAGE__], -1, $path);
        # now overwrite the path in place to see if the location pointer
        # is really copied: see modperl_config_dir_create
        $path=~tr[a-z][n-za-m];
    };

    return Apache2::Const::DECLINED;
}

sub fixup {
    my ($r) = @_;

    eval {
        $r->add_config(['Options ExecCGI'], -1, '/',
                       Apache2::Const::OPT_EXECCGI);
    };
    $r->pnotes(add_config3 => "$@");

    eval {
        $r->server->add_config(['ServerAdmin foo@bar.com']);
    };
    $r->pnotes(add_config4 => "$@");

    return Apache2::Const::DECLINED;
}

sub handler : method {
    my ($self, $r) = @_;
    my $cf = $self->get_config($r->server);

    plan $r, tests => 9;

    ok t_cmp $r->pnotes('add_config1'), qr/.+\n/;
    ok t_cmp $r->pnotes('add_config2'), (APACHE22 ? qr/.+\n/ : '');
    ok t_cmp $r->pnotes('add_config3'), '';
    ok t_cmp $r->pnotes('add_config4'), qr/after server startup/;
    if (!APACHE24) {
        ok t_cmp $r->pnotes('followsymlinks'), (APACHE22 ? '': qr/.*\n/);
    }
    else {
        ok 1;
    }

    my $expect =  Apache2::Const::OPT_ALL |
                  Apache2::Const::OPT_UNSET |
                  (defined &Apache2::Const::OPT_INCNOEXEC
                   ? Apache2::Const::OPT_INCNOEXEC() : 0) |
                  Apache2::Const::OPT_MULTI |
                  Apache2::Const::OPT_SYM_OWNER;

    ok t_cmp $cf->{override_opts}, $expect;
    ok t_cmp $r->allow_options, Apache2::Const::OPT_EXECCGI;

    my $opts = APACHE22 ? Apache2::Const::OPT_SYM_LINKS : $expect;
    if (!APACHE24) {
        ok t_cmp $r->allow_override_opts, $opts;
    }
    else {
        ok 1;
    }

    ok t_cmp $r->location, '/a/path/to/somewhere';

    return Apache2::Const::OK;
}

1;
__END__

# APACHE_TEST_CONFIG_ORDER 950
<NoAutoConfig>
    <VirtualHost TestAPI::add_config>
        PerlLoadModule TestAPI::add_config
        AccessFileName htaccess
        SetHandler modperl
        <Directory @DocumentRoot@>
            AllowOverride All
        </Directory>
        PerlMapToStorageHandler TestAPI::add_config::map2storage
        PerlFixupHandler TestAPI::add_config::fixup
    </VirtualHost>
</NoAutoConfig>
