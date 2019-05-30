# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestProtocol::pseudo_http;

# this is a more advanced protocol implementation. While using a
# simplistic socket communication, the protocol uses an almost
# complete HTTP AAA (access and authentication, but not authorization,
# which can be easily added) provided by mod_auth (but can be
# implemented in perl too)
#
# see the protocols.pod document for the explanations of the code

use strict;
use warnings FATAL => 'all';

use Apache2::Connection ();
use Apache2::RequestUtil ();
use Apache2::HookRun ();
use Apache2::Access ();
use APR::Socket ();

use Apache::TestTrace;

use Apache2::Const -compile => qw(OK DONE DECLINED);
use APR::Const -compile => qw(SO_NONBLOCK);

my @cmds = qw(date quit);
my %commands = map { $_, \&{$_} } @cmds;

sub handler {
    my $c = shift;
    my $socket = $c->client_socket;

    if ($socket->opt_get(APR::Const::SO_NONBLOCK)) {
        $socket->opt_set(APR::Const::SO_NONBLOCK => 0);
    }

    if ((my $rc = greet($c)) != Apache2::Const::OK) {
        $socket->send("Say HELO first\n");
        return $rc;
    }

    if ((my $rc = login($c)) != Apache2::Const::OK) {
        $socket->send("Access Denied\n");
        return $rc;
    }

    $socket->send("Welcome to " . __PACKAGE__ .
                  "\nAvailable commands: @cmds\n");

    while (1) {
        my $cmd;
        next unless $cmd = getline($socket);

        if (my $sub = $commands{$cmd}) {
            last unless $sub->($socket) == Apache2::Const::OK;
        }
        else {
            $socket->send("Commands: @cmds\n");
        }
    }

    return Apache2::Const::OK;
}

sub greet {
    my $c = shift;
    my $socket = $c->client_socket;

    $socket->send("HELO\n");
    my $reply = getline($socket) || '';

    return $reply eq 'HELO' ?  Apache2::Const::OK : Apache2::Const::DECLINED;
}

sub login {
    my $c = shift;

    my $r = Apache2::RequestRec->new($c);

    # test whether we can invoke modperl HTTP handlers on the fake $r
    $r->push_handlers(PerlAccessHandler => \&my_access);

    $r->location_merge(__PACKAGE__);

    for my $method (qw(run_access_checker run_check_user_id
                       run_auth_checker)) {

        my $rc = $r->$method();

        if ($rc != Apache2::Const::OK and $rc != Apache2::Const::DECLINED) {
            return $rc;
        }

        last unless $r->some_auth_required;

        unless ($r->user) {
            my $socket = $c->client_socket;

            my $username = prompt($socket, "Login");
            my $password = prompt($socket, "Password");

            $r->set_basic_credentials($username, $password);
        }
    }

    return Apache2::Const::OK;
}

sub my_access {
    # just test that we can invoke a mod_perl HTTP handler
    debug "running my_access";
    return Apache2::Const::OK;
}

sub getline {
    my $socket = shift;

    my $line;
    $socket->recv($line, 1024);
    return unless $line;
    $line =~ s/[\r\n]*$//;

    return $line;
}

sub prompt {
    my ($socket, $msg) = @_;

    $socket->send("$msg:\n");
    getline($socket);
}

sub date {
    my $socket = shift;

    $socket->send("The time is: " . scalar(localtime) . "\n");

    return Apache2::Const::OK;
}

sub quit {
    my $socket = shift;

    $socket->send("Goodbye\n");

    return Apache2::Const::DONE
}

1;
__END__
<NoAutoConfig>
<VirtualHost TestProtocol::pseudo_http>

  PerlProcessConnectionHandler TestProtocol::pseudo_http

  <Location TestProtocol::pseudo_http>

      <IfModule mod_version.c>
          <IfVersion < 2.3.0>
              <IfModule @ACCESS_MODULE@>
                  Order Deny,Allow
                  Allow from @servername@
              </IfModule>
          </IfVersion>
          <IfVersion > 2.4.1>
              <IfModule mod_access_compat.c>
                  Order Deny,Allow
                  Allow from @servername@
              </IfModule>
          </IfVersion>
      </IfModule>

      <IfModule @AUTH_MODULE@>
          # htpasswd -mbc basic-auth stas foobar
          # using md5 password so it'll work on win32 too
          AuthUserFile @ServerRoot@/htdocs/protocols/basic-auth
      </IfModule>

      AuthName TestProtocol::pseudo_http
      AuthType Basic
      Require user stas
      <IfModule mod_version.c>
          <IfVersion < 2.3.0>
              Satisfy any
          </IfVersion>
          <IfVersion > 2.4.1>
              <IfModule mod_access_compat.c>
                  Satisfy any
              </IfModule>
          </IfVersion>
      </IfModule>

  </Location>

</VirtualHost>
</NoAutoConfig>
