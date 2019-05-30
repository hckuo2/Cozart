# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest ();

my $module = 'TestProtocol::pseudo_http';

{
    # debug
    Apache::TestRequest::module($module);
    my $hostport = Apache::TestRequest::hostport(Apache::Test::config());
    t_debug("connecting to $hostport");
}

my $login    = "stas";
my $passgood = "foobar";
my $passbad  = "foObaR";

# blocking socket bug fixed in 2.0.52
my $ok = $^O !~ /^(Open|Net)BSD$/i || need_min_apache_version('2.0.52');

my @modules = ();
push @modules, 'mod_access_compat.c' if have_min_apache_version("2.4.0");
plan tests => 13, need need_auth, need_access, @modules, $ok;

{
    # supply correct credential when prompted for such and ask the
    # server get the secret datetime information
    my $socket = Apache::TestRequest::vhost_socket($module);
    ok $socket;

    ####################################################################
    # ACTION     SEND     RECEIVE
    #
    # greeting   HELO
    #                     HELO
    #                     Login:
    #
    # login      $login
    #                     Password
    #
    # good pass  $passgood
    # banner              Welcome to TestProtocol::pseudo_http
    #                     Available commands: date quit
    # date       date
    #                     The time is: Sat Jul  8 23:51:47 2006
    #
    # eot        quit
    #                     Goodbye

    {
        my $response = "";
        $response = Send($socket, 'HELO');
        ok t_cmp($response, 'HELO', 'greeting 1');
        $response = getline($socket);
        ok t_cmp($response, 'Login:', 'greeeting 2')
    }

    {
        my $response = Send($socket, $login);
        ok t_cmp($response, 'Password:', 'login');
    }

    {
        my $response = "";
        $response = Send($socket, $passgood);
        ok t_cmp($response, 'Welcome to TestProtocol::pseudo_http', 'good pass');
        $response = getline($socket);
        ok t_cmp($response, 'Available commands: date quit', 'banner');
    }

    {
        my $response = Send($socket, 'date');
        ok t_cmp($response, qr/The time is:/, 'date');
    }

    {
        my $response = Send($socket, 'quit');
        ok t_cmp($response, 'Goodbye', 'eot');
    }
}

{
    # supply correct credential when prompted for such and ask the
    # server get the secret datetime information
    my $socket = Apache::TestRequest::vhost_socket($module);
    ok $socket;

    ####################################################################
    # ACTION     SEND     RECEIVE
    #
    # greeting   HELO
    #                     HELO
    #                     Login:
    #
    # login      $login
    #                     Password
    #
    # bad pass   $passbad
    #                     Access Denied
    #
    # eot        quit
    #                     Goodbye

    {
        my $response = "";
        $response = Send($socket, 'HELO');
        ok t_cmp($response, 'HELO', 'greeting 1');
        $response = getline($socket);
        ok t_cmp($response, 'Login:', 'greeeting 2')
    }

    {
        my $response = Send($socket, $login);
        ok t_cmp($response, 'Password:', 'login');
    }

    {
        my $response = "";
        $response = Send($socket, $passbad);
        ok t_cmp($response, 'Access Denied', 'eot');
    }
}

## send() is reserved
sub Send {
    my ($socket, $str) = @_;

    t_debug("send: $str");
    print $socket $str;

    chomp(my $recv = <$socket> || '');
    t_debug("recv: $recv");

    return $recv;
}

sub getline {
    my ($socket) = @_;

    chomp(my $recv = <$socket> || '');
    t_debug("getline: $recv");

    return $recv;
}
