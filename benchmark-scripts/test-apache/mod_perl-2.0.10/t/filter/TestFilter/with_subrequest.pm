package TestFilter::with_subrequest;

use strict;
use warnings FATAL => 'all';

use Apache2::Filter ();
use Apache2::SubRequest ();

use TestCommon::Utils;

use Apache2::Const -compile => 'OK';

sub handler {
    my $f = shift;
    my $r = $f->r;

    my $subr;
    while ($f->read(my $buffer, 1024)) {
        $f->print(lc $buffer);
	if (!$subr) {
            $subr = $r->lookup_uri($r->uri);
            my $rc = $subr->run;
        }
    }

    Apache2::Const::OK;
}

1;
__DATA__

<Location /with_subrequest>
  PerlOutputFilterHandler TestFilter::with_subrequest
</Location>

<IfModule mod_alias.c>
    Alias /with_subrequest @top_dir@
</IfModule>
