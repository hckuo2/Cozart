# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestAPI::rflush;

use strict;
use warnings FATAL => 'all';

# this test verifies that rflush flushes bucket brigades

use Apache::Test;
use Apache::TestUtil;

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use Apache2::Filter ();

use Apache2::Const -compile => qw(OK);

use constant READ_SIZE  => 1024;

sub bracket {
      my $filter = shift;

      my $data = '';

      while ($filter->read(my $buffer, 1024)) {
          $data .= $buffer;
      }

      $filter->print("[$data]") if $data;

      return Apache2::Const::OK;
}

sub response {
    my $r = shift;

    $r->content_type('text/plain');

    my $args = $r->args || '';
    if ($args eq 'nontied') {
        # print is now unbuffered
        local $| = 1;
        $r->print("1"); # send the data in the buffer + flush bucket
        $r->print("2"); # send the data in the buffer + flush bucket

        # print is now buffered
        local $| = 0;
        $r->print("3");
        $r->rflush;     # send the data in the buffer + flush bucket
        $r->print("4");
        $r->rflush;     # send the data in the buffer + flush bucket
        $r->print("5");
        $r->print("6"); # send the data in the buffer (end of handler)
    }
    elsif ($args eq 'tied') {
        my $oldfh;
        # print is now unbuffered ("rflush"-like functionality is
        # called internally)
        $oldfh = select(STDOUT); $| = 1; select($oldfh);
        print "1"; # send the data in the buffer + flush bucket
        print "2";

        # print is now buffered
        $oldfh = select(STDOUT); $| = 0; select($oldfh);
        print "3";
        print "4";
        print "5";
        print "6"; # send the data in the buffer (end of handler)
    }

    Apache2::Const::OK;
}
1;
__DATA__
SetHandler perl-script
PerlModule              TestAPI::rflush
PerlResponseHandler     TestAPI::rflush::response
PerlOutputFilterHandler TestAPI::rflush::bracket
