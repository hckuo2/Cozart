# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCommon::LogDiff;

use strict;
use warnings FATAL => 'all';

use POSIX ();

sub new {
    my $class = shift;
    my $path  = shift;

    open my $fh, "<$path" or die "Can't open $path: $!";
    seek $fh, 0, POSIX::SEEK_END();
    my $pos = tell $fh;

    my %self = (
        path => $path,
        fh   => $fh,
        pos  => $pos,
    );

    return bless \%self, $class;
}

sub DESTROY {
    my $self = shift;
    close $self->{fh};
}

sub diff {
    my $self = shift;

    # XXX: is it possible that some system will be slow to flush the
    # buffers and we may need to wait a bit and retry if we see no new
    # logged data?
    my $fh = $self->{fh};
    seek $fh, $self->{pos}, POSIX::SEEK_SET(); # not really needed

    local $/; # slurp mode
    my $diff = <$fh>;
    seek $fh, 0, POSIX::SEEK_END();
    $self->{pos} = tell $fh;

    return defined $diff ? $diff : '';
}

1;

__END__

=head1 NAME

TestCommon::LogDiff - get log file diffs

=head1 Synopsis

  use TestCommon::LogDiff;
  use Apache::Test;

  plan tests => 2;

  my $path = "/tmp/mylog";
  open my $fh, ">>$path" or die "Can't open $path: $!";

  my $logdiff = TestCommon::LogDiff->new($path);

  print $fh "foo 123\n";
  my $expected = qr/^foo/;
  ok t_cmp $logdiff->diff, $expected;

  print $fh "bar\n";
  my $expected = 'bar';
  ok t_cmp $logdiff->diff, $expected;


=head1 Description

Useful for testing the warning, error and other messages going into
the log file.

=head1 API

=head2 new

open the log file and point the filehandle pointer to its end.

=head2 diff

extract any newly logged information since the last check and move the
filehandle to the end of the file.

=cut

