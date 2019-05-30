# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPRlib::util;

# test APR::Util

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use APR::Util ();

use constant CRYPT_WORKS => $^O !~ /^(MSWin32|beos|NetWare)$/;

my $clear = "this is some text";
# to get the hash values used:
# htpasswd -nb[sm] user "this is some text"
my %hashes = (
    crypt => 'pHM3JfnL6isho',
    md5   => '$apr1$Kld6H/..$o5OPPPWslI3zB20S54u9s1',
    sha1  => '{SHA}A5NpTRa4TethLkfOYlK9NfDYbAY=',
);

# BACK_COMPAT_MARKER (sha1 support added in 2.0.50)
delete $hashes{sha1} unless have_min_apache_version('2.0.50');

sub num_of_tests {
    return 1 + scalar keys %hashes;
}

sub test {

    # password_validate
    {
        ok ! APR::Util::password_validate("one", "two");

        while (my ($mode, $hash) = each %hashes) {
            t_debug($mode);
            if ($mode eq 'crypt' && !CRYPT_WORKS) {
                t_debug("crypt is not supported on $^O");
                ok 1; # don't make noise
            }
            else {
                ok APR::Util::password_validate($clear, $hash);
            }
        }
    }

#this function seems unstable on certain platforms
#    my $blen = 10;
#    my $bytes = APR::generate_random_bytes($blen);
#    ok length($bytes) == $blen;

}

1;
