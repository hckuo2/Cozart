# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestModules::cgi;

use strict;
use warnings FATAL => 'all';

use Apache2::compat ();
use CGI ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    unless ($ENV{MOD_PERL}) {
        die "\$ENV{MOD_PERL} is not set";
    }

    unless ($ENV{MOD_PERL_API_VERSION} == 2) {
        die "\$ENV{MOD_PERL_API_VERSION} is not set";
    }

    if ($CGI::Q) {
        die "CGI.pm globals were not reset";
    }

    unless ($CGI::MOD_PERL) {
        die "CGI.pm does not think this is mod_perl";
    }

    my $cgi = CGI->new;

    my $param = $cgi->param('PARAM');
    my $httpupload = $cgi->param('HTTPUPLOAD');

    print $cgi->header('-type' => 'text/test-output',
                       '-X-Perl-Module' => __PACKAGE__);

    if ($httpupload) {
        no strict;
        local $/;
        my $content = <$httpupload>;
        print "ok $content";
    }
    elsif ($param) {
        print "ok $param";
    }
    else {
        print "no param or upload data\n";
    }

    Apache2::Const::OK;
}

1;
__END__
SetHandler perl-script
PerlOptions -SetupEnv
