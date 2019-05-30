# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
# test env vars

use Apache2::URI ();
use Apache2::Const -compile => qw(REDIRECT SERVER_ERROR);

my $r = shift;
my $path = $r->args || '';
$server = $r->construct_server;

$r->err_headers_out->set('Set-Cookie' => "mod_perl=ubercool; path=/");
$r->headers_out->set(Location => " http://$server$path");
$r->status(Apache2::Const::REDIRECT);

# exit status is completely ignored in Registry
# due to $r->status hacking
return Apache2::Const::SERVER_ERROR;

__END__
