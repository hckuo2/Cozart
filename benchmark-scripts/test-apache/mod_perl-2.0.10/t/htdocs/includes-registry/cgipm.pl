# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
use Apache2::compat ();
use CGI ();

my $cgi = CGI->new;

print $cgi->header;

print "cgi.pm\n";

__END__
