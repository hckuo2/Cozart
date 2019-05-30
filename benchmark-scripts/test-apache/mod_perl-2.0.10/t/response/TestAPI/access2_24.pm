package TestAPI::access2_24;

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
                                  AUTHZ_GRANTED AUTHZ_DENIED M_POST :satisfy
                                  AUTHZ_DENIED_NO_USER);

my $users  = "goo bar";
my $groups = "xar tar";
my %users = (
    goo => "goopass",
    bar => "barpass",
);

sub authz_handler {
    my $self = shift;
    my $r = shift;
    my $requires = shift;

    if (!$r->user) {
        return Apache2::Const::AUTHZ_DENIED_NO_USER;
    }

    return Apache2::Const::SERVER_ERROR unless
        $requires eq $users or $requires eq $groups;

    my @require_args = split(/\s+/, $requires);
    if (grep {$_ eq $r->user} @require_args) {
        return Apache2::Const::AUTHZ_GRANTED;
    }

    return Apache2::Const::AUTHZ_DENIED;
}

sub authn_handler {
    my $self = shift;
    my $r = shift;

    die '$r->some_auth_required failed' unless $r->some_auth_required;

    my $satisfies = $r->satisfies;
    die "wanted satisfies=" . Apache2::Const::SATISFY_ALL . ", got $satisfies"
        unless $r->satisfies() == Apache2::Const::SATISFY_ALL;

    my ($rc, $sent_pw) = $r->get_basic_auth_pw;
    return $rc if $rc != Apache2::Const::OK;

    if ($r->method_number == Apache2::Const::M_POST) {
        return Apache2::Const::OK;
    }

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
<IfVersion > 2.4.1>

PerlAddAuthzProvider my-user TestAPI::access2_24->authz_handler
PerlAddAuthzProvider my-group TestAPI::access2_24->authz_handler
<Location /TestAPI__access2>
    PerlAuthenHandler TestAPI::access2_24->authn_handler
    PerlResponseHandler Apache::TestHandler::ok1
    SetHandler modperl

    <IfModule mod_access_compat.c>
        # needed to test $r->satisfies
        Allow from All
    </IfModule>
    AuthType Basic
    AuthName "Access"
    Require my-user goo bar
    Require my-group xar tar
    <Limit POST>
       Require valid-user
    </Limit>
    <IfModule mod_access_compat.c>
        Satisfy All
    </IfModule>
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
