# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::out_str_remove;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Filter ();

use Apache2::Const -compile => qw(OK);

use constant READ_SIZE  => 1024;

# this filter reads the first bb, upcases the data in it and removes itself
sub upcase_n_remove {
      my $filter = shift;

      #warn "filter upcase_n_remove called\n";
      while ($filter->read(my $buffer, 1024)) {
          $filter->print(uc $buffer);
      }

      $filter->remove;

      return Apache2::Const::OK;
}

# this filter inserts underscores after each character it receives
sub insert_underscores {
      my $filter = shift;

      #warn "filter insert_underscores called\n";
      while ($filter->read(my $buffer, 1024)) {
          $buffer =~ s/(.)/$1_/g;
          $filter->print($buffer);
      }

      return Apache2::Const::OK;
}


sub response {
    my $r = shift;

    # just to make sure that print() won't flush, or we would get the
    # count wrong
    local $| = 0;

    $r->content_type('text/plain');
    $r->print("Foo");
    $r->rflush;     # this sends the data in the buffer + flush bucket
    $r->print("bar");

    Apache2::Const::OK;
}
1;
__DATA__
SetHandler modperl
PerlModule              TestFilter::out_str_remove
PerlResponseHandler     TestFilter::out_str_remove::response
PerlOutputFilterHandler TestFilter::out_str_remove::insert_underscores
PerlOutputFilterHandler TestFilter::out_str_remove::upcase_n_remove
