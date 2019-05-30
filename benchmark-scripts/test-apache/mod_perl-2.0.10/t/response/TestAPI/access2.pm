# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::access2;

# testing $r->requires
# in the POST test it returns:
#
#  [
#    {
#      'method_mask' => -1,
#      'requirement' => 'user goo bar'
#    },
#    {
#      'method_mask' => -1,
#      'requirement' => 'group bar tar'
#    }
#    {
#      'method_mask' => 4,
#      'requirement' => 'valid-user'
#    }
#  ];
#
# otherwise it returns the same, sans the 'valid-user' entry
#
# also test:
# - $r->some_auth_required when it's required
# - $r->satisfies when Satisfy is set

use strict;
use warnings FATAL => 'all';

use Apache2::Access ();
use Apache2::RequestRec ();

use Apache::TestTrace;

use Apache2::Const -compile => qw(OK HTTP_UNAUTHORIZED SERVER_ERROR
                                 M_POST :satisfy);

my $users  = "goo bar";
my $groups = "bar tar";
my %users = (
    goo => "goopass",
    bar => "barpass",
);

sub handler {
    my $r = shift;
    die '$r->some_auth_required failed' unless $r->some_auth_required;

    my $satisfies = $r->satisfies;
    die "wanted satisfies=" . Apache2::Const::SATISFY_ALL . ", got $satisfies"
        unless $r->satisfies() == Apache2::Const::SATISFY_ALL;

    my ($rc, $sent_pw) = $r->get_basic_auth_pw;
    return $rc if $rc != Apache2::Const::OK;

    # extract just the requirement entries
    my %require =
        map { my ($k, $v) = split /\s+/, $_->{requirement}, 2; ($k, $v||'') }
        @{ $r->requires };
    debug \%require;

    # silly (we don't check user/pass here), just checking when
    # the Limit options are getting through
    if ($r->method_number == Apache2::Const::M_POST) {
        if (exists $require{"valid-user"}) {
            return Apache2::Const::OK;
        }
        else {
            return Apache2::Const::SERVER_ERROR;
        }
    }
    else {
        # non-POST requests shouldn't see the Limit enclosed entry
        return Apache2::Const::SERVER_ERROR if exists $require{"valid-user"};
    }

    return Apache2::Const::SERVER_ERROR unless $require{user}  eq $users;
    return Apache2::Const::SERVER_ERROR unless $require{group} eq $groups;

    my $user = $r->user;
    my $pass = $users{$user} || '';
    unless (defined $pass and $sent_pw eq $pass) {
        $r->note_basic_auth_failure;
        return Apache2::Const::HTTP_UNAUTHORIZED;
    }

    Apache2::Const::OK;
}

1;
__DATA__

<NoAutoConfig>
<IfModule mod_version.c>
<IfVersion < 2.3.0>
<Location /TestAPI__access2>
    PerlAuthenHandler TestAPI::access2
    PerlResponseHandler Apache::TestHandler::ok1
    SetHandler modperl

    <IfModule @ACCESS_MODULE@>
        # needed to test $r->satisfies
        Allow from All
    </IfModule>
    AuthType Basic
    AuthName "Access"
    Require user goo bar
    Require group bar tar
    <Limit POST>
       Require valid-user
    </Limit>
    Satisfy All
    <IfModule @AUTH_MODULE@>
        # htpasswd -mbc auth-users goo foo
        # htpasswd -mb auth-users bar mar
        # using md5 password so it'll work on win32 too
        AuthUserFile @DocumentRoot@/api/auth-users
        # group: user1 user2 ...
        AuthGroupFile @DocumentRoot@/api/auth-groups
    </IfModule>
</Location>
</IfVersion>
</IfModule>
</NoAutoConfig>
