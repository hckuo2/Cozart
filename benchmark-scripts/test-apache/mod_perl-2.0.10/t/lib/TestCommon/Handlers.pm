# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCommon::Handlers;

use strict;
use warnings FATAL => 'all';

use Apache2::RequestRec ();
use Apache2::RequestIO ();

use TestCommon::Utils ();

use Apache::TestTrace;

use Apache2::Const -compile => qw(M_POST OK);

# read the posted body and send it back to the client as is
sub pass_through_response_handler {
    my $r = shift;

    if ($r->method_number == Apache2::Const::M_POST) {
        my $data = TestCommon::Utils::read_post($r);
        debug "pass_through_handler read: $data\n";
        $r->print($data);
    }

    Apache2::Const::OK;
}

1;

__END__

=head1 NAME

TestCommon::Handlers - Common Handlers



=head1 Synopsis

  # PerlModule          TestCommon::Handlers
  # PerlResponseHandler TestCommon::Handlers::pass_through_response_handler


=head1 Description

Various commonly used handlers




=head1 API

=head2 pass_through_response_handler

  # PerlModule          TestCommon::Handlers
  # PerlResponseHandler TestCommon::Handlers::pass_through_response_handler

this is a response handler, which reads the posted body and sends it
back to the client as is.

=cut
