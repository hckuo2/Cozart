# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
my $r = shift;
$r->content_type('text/plain');
$r->print('ok');
