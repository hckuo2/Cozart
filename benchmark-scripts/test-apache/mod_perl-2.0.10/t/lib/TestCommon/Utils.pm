# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCommon::Utils;

use strict;
use warnings FATAL => 'all';

use APR::Brigade ();
use APR::Bucket ();
use Apache2::Filter ();
use Apache2::Connection ();

use Apache2::Const -compile => qw(MODE_READBYTES);
use APR::Const    -compile => qw(SUCCESS BLOCK_READ);

use constant IOBUFSIZE => 8192;

# perl 5.6.x only triggers taint protection on strings which are at
# least one char long
sub is_tainted {
    return ! eval {
        eval join '', '#',
            map defined() ? substr($_, 0, 0) : (), @_;
        1;
    };
}

# to enable debug start with: (or simply run with -trace=debug)
# t/TEST -trace=debug -start
sub read_post {
    my $r = shift;
    my $debug = shift || 0;

    my $bb = APR::Brigade->new($r->pool,
                               $r->connection->bucket_alloc);

    my $data = '';
    my $seen_eos = 0;
    my $count = 0;
    do {
        $r->input_filters->get_brigade($bb, Apache2::Const::MODE_READBYTES,
                                       APR::Const::BLOCK_READ, IOBUFSIZE);

        $count++;

        warn "read_post: bb $count\n" if $debug;

        while (!$bb->is_empty) {
            my $b = $bb->first;

            if ($b->is_eos) {
                warn "read_post: EOS bucket:\n" if $debug;
                $seen_eos++;
                last;
            }

            if ($b->read(my $buf)) {
                warn "read_post: DATA bucket: [$buf]\n" if $debug;
                $data .= $buf;
            }

            $b->delete;
        }

    } while (!$seen_eos);

    $bb->destroy;

    return $data;
}

1;

__END__

=head1 NAME

TestCommon::Utils - Common Test Utils



=head1 Synopsis

  use TestCommon::Utils;

  # test whether some SV is tainted
  $b->read(my $data);
  ok TestCommon::Utils::is_tainted($data);

  my $data = TestCommon::Utils::read_post($r);

=head1 Description

Various handy testing utils




=head1 API



=head2 is_tainted

  is_tainted(@data);

returns I<TRUE> if at least one element in C<@data> is tainted,
I<FALSE> otherwise.



=head2 read_post

  my $data = TestCommon::Utils::read_post($r);
  my $data = TestCommon::Utils::read_post($r, $debug);

reads the posted data using bucket brigades manipulation.

To enable debug pass a true argument C<$debug>


=cut

