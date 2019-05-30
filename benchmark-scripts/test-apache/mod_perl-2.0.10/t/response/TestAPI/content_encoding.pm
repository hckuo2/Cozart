# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::content_encoding;

# tests: $r->content_encoding("gzip");

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestUtil ();

use TestCommon::Utils ();

use Apache2::Const -compile => qw(OK DECLINED M_POST);

sub handler {
    my $r = shift;

    return Apache2::Const::DECLINED unless $r->method_number == Apache2::Const::M_POST;

    my $data = TestCommon::Utils::read_post($r);

    require Compress::Zlib;

    $r->content_type("text/plain");
    $r->content_encoding("gzip");

    $r->print(Compress::Zlib::memGzip($data));

    Apache2::Const::OK;
}

1;
__END__
