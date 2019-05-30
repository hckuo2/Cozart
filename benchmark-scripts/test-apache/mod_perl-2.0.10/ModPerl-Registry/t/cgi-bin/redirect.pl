# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
# test env vars

use Apache2::URI ();

my $r = shift;
my $path = $r->args || '';
$server = $r->construct_server;

print "Location: http://$server$path\n\n";
#warn "Location: http://$server$path\n\n";

__END__
