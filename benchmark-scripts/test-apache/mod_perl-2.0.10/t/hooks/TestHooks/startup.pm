# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::startup;

# test PerlPostConfigHandler and PerlOpenLogsHandler phases
# also test that we can run things on vhost entries from these phases

use strict;
use warnings FATAL => 'all';

use Apache::TestUtil;
use Apache::Test;
use Apache::TestTrace;

use APR::Table;
use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();

use File::Spec::Functions qw(catfile catdir);
use File::Path qw(mkpath);

use Apache2::Const -compile => 'OK';

my $dir = catdir Apache::Test::vars("documentroot"), 'hooks', 'startup';

sub open_logs {
    my ($conf_pool, $log_pool, $temp_pool, $s) = @_;

    # main server
    run("open_logs", $s);

    for (my $vhost_s = $s->next; $vhost_s; $vhost_s = $vhost_s->next) {
        my $port = $vhost_s->port;
        my $val = $vhost_s->dir_config->{PostConfig};
        # we have one vhost that we want to run open_logs for
        next unless $val && $val eq 'VHost';
        run("open_logs", $vhost_s);
    }

    Apache2::Const::OK;
}

sub post_config {
    my ($conf_pool, $log_pool, $temp_pool, $s) = @_;

    # main server
    run("post_config", $s);

    for (my $vhost_s = $s->next; $vhost_s; $vhost_s = $vhost_s->next) {
        my $port = $vhost_s->port;
        my $val = $vhost_s->dir_config->{PostConfig};
        # we have one vhost that we want to run post_config for
        next unless $val && $val eq 'VHost';
        run("post_config", $vhost_s);
    }

    Apache2::Const::OK;
}

sub run {
    my ($phase, $s) = @_;

    my $val = $s->dir_config->{PostConfig} or die "Can't read PostConfig var";

    # make sure that these are set at the earliest possible time
    die '$ENV{MOD_PERL} not set!' unless $ENV{MOD_PERL};
    die '$ENV{MOD_PERL_API_VERSION} not set!'
        unless $ENV{MOD_PERL_API_VERSION} == 2;

    my $port = $s->port;
    my $file = catfile $dir, "$phase-$port";

    mkpath $dir, 0, 0755;
    open my $fh, ">$file" or die "can't open $file: $!";
    print $fh $val;
    close $fh;

    debug "Phase $phase is completed for server at port $port";
}

sub handler {
    my $r = shift;

    $r->content_type('text/plain');

    my $s = $r->server;
    my $expected = $s->dir_config->{PostConfig}
        or die "Can't read PostConfig var";
    my $port = $s->port;

    for my $phase (qw(open_logs post_config)) {
        my $file = catfile $dir, "$phase-$port";
        open my $fh, "$file" or die "can't open $file: $!";
        my $received = <$fh> || '';
        close $fh;

        # can't cleanup the file here, because t/SMOKE may run this
        # test more than once, so we cleanup on startup in modperl_extra.pl
        # unlink $file;

        if ($expected eq $received) {
            $r->print("$phase ok\n");
        } else {
            warn "phase: $phase\n";
            warn "port: $port\n";
            warn "expected: $expected\n";
            warn "received: $received\n";
        }
    }
    Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
<VirtualHost TestHooks::startup>
    PerlSetVar PostConfig VHost
    PerlModule TestHooks::startup
    PerlPostConfigHandler TestHooks::startup::post_config
    PerlOpenLogsHandler   TestHooks::startup::open_logs
    <Location /TestHooks__startup>
        SetHandler modperl
        PerlResponseHandler TestHooks::startup
    </Location>
</VirtualHost>
PerlSetVar PostConfig Main
PerlModule TestHooks::startup
PerlPostConfigHandler TestHooks::startup::post_config
PerlOpenLogsHandler   TestHooks::startup::open_logs
<Location /TestHooks__startup>
    SetHandler modperl
    PerlResponseHandler TestHooks::startup
</Location>
</NoAutoConfig>
