# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestProtocol::echo_filter;

# see also TestFilter::both_str_con_add

use strict;
use warnings FATAL => 'all';

use Apache2::Connection ();
use APR::Socket ();
use APR::Bucket ();
use APR::Brigade ();
use APR::Error ();

use base qw(Apache2::Filter);

use APR::Const    -compile => qw(SUCCESS SO_NONBLOCK);
use APR::Status ();
use Apache2::Const -compile => qw(OK MODE_GETLINE);

use constant BUFF_LEN => 1024;

sub uc_filter : FilterConnectionHandler {
    my $filter = shift;

    while ($filter->read(my $buffer, BUFF_LEN)) {
        $filter->print(uc $buffer);
    }

    return Apache2::Const::OK;
}

sub handler {
    my $c = shift;

    # starting from Apache 2.0.49 several platforms require you to set
    # the socket to a blocking IO mode
    $c->client_socket->opt_set(APR::Const::SO_NONBLOCK, 0);

    my $bb = APR::Brigade->new($c->pool, $c->bucket_alloc);

    while (1) {
        my $rc = $c->input_filters->get_brigade($bb, Apache2::Const::MODE_GETLINE);
        last if APR::Status::is_EOF($rc);
        die APR::Error::strerror($rc) unless $rc == APR::Const::SUCCESS;

        # fflush is the equivalent of the following 3 lines of code:
        #
        # my $b = APR::Bucket::flush_create($c->bucket_alloc);
        # $bb->insert_tail($b);
        # $c->output_filters->pass_brigade($bb);
        $c->output_filters->fflush($bb);
    }

    $bb->destroy;

    Apache2::Const::OK;
}

1;
__END__
PerlModule              TestProtocol::echo_filter
PerlOutputFilterHandler TestProtocol::echo_filter::uc_filter

