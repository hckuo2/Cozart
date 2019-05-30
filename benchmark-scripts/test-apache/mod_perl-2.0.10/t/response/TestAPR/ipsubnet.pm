# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPR::ipsubnet;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::Connection ();
use Apache2::RequestRec ();
use APR::Pool ();
use APR::IpSubnet ();
use APR::SockAddr ();

use Apache2::Const -compile => 'OK';
use constant APACHE24   => have_min_apache_version('2.4.0');

sub handler {
    my $r = shift;
    my $c = $r->connection;
    my $p = $r->pool;

    plan $r, tests => 8;

    my $ip = APACHE24 ? $c->client_ip : $c->remote_ip;

    ok $ip;

    if (APACHE24) {
        ok t_cmp($c->client_addr->ip_get, $ip,
                "client_ip eq client_addr->ip_get");
    }
    else {
        ok t_cmp($c->remote_addr->ip_get, $ip,
                "remote_ip eq remote_addr->ip_get");
    }

    {
        my $ipsub = APR::IpSubnet->new($p, $ip);

        ok $ipsub->test(APACHE24 ? $c->client_addr : $c->remote_addr);
    }

    # use IP mask
    {
        my $ipsub = APR::IpSubnet->new($p, $ip, "255.0.0.0");

        ok $ipsub->test(APACHE24 ? $c->client_addr : $c->remote_addr);
    }

    # fail match
    {
        if ($ip =~ /^\d+\.\d+\.\d+\.\d+$/) {
            # arrange for the subnet to match only one IP, which is
            # one digit off the client IP, ensuring a mismatch
            (my $mismatch = $ip) =~ s/(?<=\.)(\d+)$/$1 == 255 ? $1-1 : $1+1/e;
            t_debug($mismatch);
            my $ipsub = APR::IpSubnet->new($p, $mismatch, $mismatch);
            ok ! $ipsub->test(APACHE24 ? $c->client_addr : $c->remote_addr);
        }
        else {
            # XXX: similar ipv6 trick?
            ok 1;
        }
    }

    # bogus IP
    {
        my $ipsub = eval { APR::IpSubnet->new($p, "345.234.678.987") };
        ok t_cmp($@, qr/The specified IP address is invalid/, "bogus IP");
    }

    # bogus mask
    {
        my $ipsub = eval { APR::IpSubnet->new($p, $ip, "255.0") };
        ok t_cmp($@, qr/The specified network mask is invalid/, "bogus mask");
    }

    # temp pool
    {
        my $ipsub = APR::IpSubnet->new(APR::Pool->new, $ip);
        # try to overwrite the temp pool data
        require APR::Table;
        my $table = APR::Table::make(APR::Pool->new, 50);
        $table->set($_ => $_) for 'aa'..'za';
        # now test that we are still OK
        ok $ipsub->test(APACHE24 ? $c->client_addr : $c->remote_addr);
    }

    Apache2::Const::OK;
}

1;
