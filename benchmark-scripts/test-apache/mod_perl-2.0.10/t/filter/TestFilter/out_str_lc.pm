# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_str_lc;

use strict;
use warnings FATAL => 'all';

use Apache2::Filter ();

use TestCommon::Utils;

use Apache2::Const -compile => 'OK';

sub handler {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {

        # test that read() returns tainted data
        die "read() has returned untainted data"
            unless TestCommon::Utils::is_tainted($buffer);

        $filter->print(lc $buffer);
    }

    Apache2::Const::OK;
}

1;
__DATA__

<Location /top_dir>
  PerlOutputFilterHandler TestFilter::out_str_lc
</Location>
<IfModule mod_alias.c>
    Alias /top_dir @top_dir@
</IfModule>
