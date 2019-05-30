# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestHooks::cleanup;

# test various ways to assign cleanup handlers

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use File::Spec::Functions qw(catfile);

use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();

use Apache2::Const -compile => qw(OK DECLINED);

sub get_file {
    catfile Apache::Test::vars("documentroot"), "hooks", "cleanup";
}

sub handler {
    my $r = shift;

    $r->content_type('text/plain');
    $r->print('ok');
    $r->pnotes(items => ["cleanup"," ok"]);
    $r->push_handlers(PerlCleanupHandler => \&cleanup2);

    return Apache2::Const::OK;
}

sub cleanup1 {
    my $r = shift;

    my $items = $r->pnotes('items');
    die "no items" unless $items;
    my $item = $items ? $items->[0] : '';
    #warn "cleanup CALLED\n";
    t_write_file(get_file(), $item);

    return Apache2::Const::OK;
}

sub cleanup2 {
    my $r = shift;

    my $items = $r->pnotes('items');
    my $item = $items ? $items->[1] : '';
    #warn "cleanup2 CALLED\n";
    t_append_file(get_file(), $item);

    return Apache2::Const::OK;
}

1;
__DATA__
<NoAutoConfig>
  <Location /TestHooks__cleanup>
      SetHandler modperl
      PerlCleanupHandler  TestHooks::cleanup::cleanup1
      PerlResponseHandler TestHooks::cleanup
  </Location>
</NoAutoConfig>

