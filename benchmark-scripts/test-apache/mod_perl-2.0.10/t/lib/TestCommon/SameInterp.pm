# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCommon::SameInterp;

use Apache::Test;
use Apache::TestUtil;

use Exporter;
use vars qw(@ISA @EXPORT);

@ISA = qw(Exporter);

@EXPORT = qw(same_interp_req same_interp_req_body
             same_interp_skip_not_found);

sub same_interp_req {
    my $res = eval {
        Apache::TestRequest::same_interp_do(@_);
    };
    return undef if $@ && $@ =~ /unable to find interp/;
    die $@ if $@;
    return $res;
}

sub same_interp_req_body {
    my $res = same_interp_req(@_);
    return $res ? $res->content : "";
}

sub same_interp_skip_not_found {
    my $skip_cond = shift;
    if ($skip_cond) {
        skip "Skip couldn't find the same interpreter", 0;
    }
    else {
        my ($package, $filename, $line) = caller;
        # trick ok() into reporting the caller filename/line when a
        # sub-test fails in sok()
        return eval <<EOE;
#line $line $filename
    ok &t_cmp;
EOE
    }
}

1;

__END__

=head1 NAME

TestCommon::SameInterp - Helper functions for same_interp framework

=head1 Synopsis

  use Apache::Test;
  use Apache::TestUtil;
  use Apache::TestRequest;

  use TestCommon::SameInterp;

  plan tests => 3;

  my $url = "/path";

  my $same_interp = Apache::TestRequest::same_interp_tie($url);
  ok $same_interp;

  my $expected = 1;
  my $skip  = 0;
  # test GET over the same same_interp
  for (1..2) {
      $expected++;
      my $res = same_interp_req($same_interp, \&GET, $url, foo => 'bar');
      $skip++ unless defined $res;
      same_interp_skip_not_found(
          $skip,
          defined $res && $res->content,
          $expected,
          "GET over the same interp"
      );
  }


=head1 Description

In addition to same_interp base blocks from Apache::TestRequest, this
helper module provides extra wrappers to simplify the writing of tests

META: consider merging those into Apache::TestRequest (or add a new
module, e.g. Apache::TestRequestSameInterp)

=head1 API



=head2 C<same_interp_req>

normally one runs:

  my $res = GET $url, @data;

in the same_interp framework one runs

  my $res = Apache::TestRequest::same_interp_do($same_interp,
      \&GET, $url, @data);

but if there is a failure to find the same interpreter we get an
exception. and there could be other exceptions as well (e.g. failure
to run the request). This wrapper handles all exceptions, returning
C<undef> if the exception was in a failure to find the same
interpreter, re-throws the exception otherwise. If there is no
exception, the response object is returned.

So one passes the same arguments to this wrapper as you'd to
Apache::TestRequest::same_interp_do:

  my $res = same_interp_req($same_interp, \&GET, $url, @data);



=head2 C<same_interp_req_body>

This function calls C<L<same_interp_req|/C_same_interp_req_>> and
extracts the response body if the response object is defined. (sort of
GET_BODY for same_interp)


=head2 C<same_interp_skip_not_found>

make the tests resistant to a failure of finding the same perl
interpreter, which happens randomly and not an error. so instead of running:

  my $res = same_interp_req($same_interp, \&GET, $url, @data);
  ok t_cmp(defined $res && $res->content, $expected, "comment")

one can run:

  my $res = same_interp_req($same_interp, \&GET, $url, @data);
  $skip = defined $res ? 0 : 1;
  same_interp_skip_not_found(
      $skip,
      defined $res && $res->content,
      $expected,
      "comment"
  );

the first argument is used to decide whether to skip the sub-test, the
rest of the arguments are passed to 'ok t_cmp'.

This wrapper is smart enough to report the correct line number as if
ok() was run in the test file itself and not in the wrapper, by doing:

  my ($package, $filename, $line) = caller;
  return eval <<EOE;
  #line $line $filename
      ok &t_cmp;
  EOE

C<&t_cmp> receives C<@_>, containing all but the skip argument, as if
the wrapper was never called.




=cut

