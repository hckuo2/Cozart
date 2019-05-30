# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestFilter::both_str_con_add;

# insert an input filter which lowers the case of the data
# insert an output filter which adjusts s/modperl/mod_perl/

# see also TestFilter::echo_filter

use strict;
use warnings FATAL => 'all';

use Apache2::Connection ();
use APR::Bucket ();
use APR::Brigade ();
use APR::Error ();
use APR::Socket;

use base qw(Apache2::Filter);

use APR::Const    -compile => qw(SUCCESS EOF SO_NONBLOCK);
use Apache2::Const -compile => qw(OK MODE_GETLINE);

sub pre_connection {
    my Apache2::Connection $c = shift;

    $c->add_input_filter(\&in_filter);
    $c->add_output_filter(\&out_filter);

    return Apache2::Const::OK;
}

sub in_filter : FilterConnectionHandler {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        $filter->print(lc $buffer);
    }

    # test that $filter->ctx works here
    $filter->ctx(1);

    Apache2::Const::OK;
}

sub out_filter : FilterConnectionHandler {
    my $filter = shift;

    while ($filter->read(my $buffer, 1024)) {
        $buffer =~ s/modperl/mod_perl/;
        $filter->print($buffer);
    }

    Apache2::Const::OK;
}

sub handler {
    my Apache2::Connection $c = shift;

    # starting from Apache 2.0.49 several platforms require you to set
    # the socket to a blocking IO mode
    $c->client_socket->opt_set(APR::Const::SO_NONBLOCK, 0);

    my $bb = APR::Brigade->new($c->pool, $c->bucket_alloc);

    for (;;) {
        $c->input_filters->get_brigade($bb, Apache2::Const::MODE_GETLINE);
        last if $bb->is_empty;

        my $b = APR::Bucket::flush_create($c->bucket_alloc);
        $bb->insert_tail($b);
        $c->output_filters->pass_brigade($bb);
        # fflush is the equivalent of the previous 3 lines of code:
        # but it's tested elsewhere, here testing flush_create
        # $c->output_filters->fflush($bb);
    }

    $bb->destroy;

    Apache2::Const::OK;
}

1;
__END__
<NoAutoConfig>
  <VirtualHost TestFilter::both_str_con_add>
      PerlModule                   TestFilter::both_str_con_add
      PerlPreConnectionHandler     TestFilter::both_str_con_add::pre_connection
      PerlProcessConnectionHandler TestFilter::both_str_con_add
  </VirtualHost>
</NoAutoConfig>


