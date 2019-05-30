# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

package Apache::SizeLimit;

use strict;
use warnings;

use Config;

use Apache::Constants ();

use constant IS_WIN32 => $Config{'osname'} eq 'MSWin32' ? 1 : 0;

use vars qw($VERSION);

$VERSION = '0.97';

use Apache::SizeLimit::Core qw(
                             $MAX_PROCESS_SIZE
                             $MAX_UNSHARED_SIZE
                             $MIN_SHARE_SIZE
                             $CHECK_EVERY_N_REQUESTS
                             $START_TIME
                             $USE_SMAPS
                             $VERSION
                             $REQUEST_COUNT
                            );
use vars qw(@ISA);
@ISA = qw(Apache::SizeLimit::Core);

__PACKAGE__->set_check_interval(1);

sub handler {
    my $r = shift || Apache->request;

    return Apache::Constants::DECLINED() unless $r->is_main();

    # we want to operate in a cleanup handler
    if ($r->current_callback eq 'PerlCleanupHandler') {
        return __PACKAGE__->_exit_if_too_big($r);
    }
    else {
        __PACKAGE__->add_cleanup_handler($r);
    }

    return Apache::Constants::DECLINED();
}

sub add_cleanup_handler {
    my $class = shift;
    my $r = shift || Apache->request;

    return unless $r;
    return if $r->pnotes('size_limit_cleanup');

    # This used to use $r->post_connection but there's no good way to
    # test it, since apparently it does not push a handler onto the
    # PerlCleanupHandler phase. That means that there's no way to use
    # $r->get_handlers() to check the results of calling this method.
    $r->push_handlers(
                      'PerlCleanupHandler',
                      sub { $class->_exit_if_too_big(shift) }
                     );
    $r->pnotes(size_limit_cleanup => 1);
}

sub _exit_if_too_big {
    my $class = shift;
    my $r = shift;

    return Apache::Constants::DECLINED()
        if ($class->get_check_interval()
             && ($class->get_and_pinc_request_count % $class->get_check_interval()));

    $class->set_start_time();

    if ($class->_limits_are_exceeded()) {
        my ($size, $share, $unshared) = $class->_check_size();

        if (IS_WIN32 || $class->_platform_getppid() > 1) {
            # this is a child httpd
            my $e   = time() - $class->get_start_time();
            my $msg = "httpd process too big, exiting at SIZE=$size KB";
            $msg .= " SHARE=$share KB UNSHARED=$unshared" if $share;
            $msg .= " REQUESTS=" . $class->get_request_count();
            $msg .= " LIFETIME=$e seconds";
            $class->_error_log($msg);

            if (IS_WIN32) {
                # child_terminate() is disabled in win32 Apache
                CORE::exit(-2);
            }
            else {
                $r->child_terminate();
            }
        }
        else {
            # this is the main httpd, whose parent is init?
            my $msg = "main process too big, SIZE=$size KB ";
            $msg .= " SHARE=$share KB" if ($share);
            $class->_error_log($msg);
        }
    }

    return Apache::Constants::OK();
}

{
    # Deprecated APIs

    sub setmax {

        my $class = __PACKAGE__;

        $class->set_max_process_size(shift);

        $class->add_cleanup_handler();
    }

    sub setmin {

        my $class = __PACKAGE__;

        $class->set_min_shared_size(shift);

        $class->add_cleanup_handler();
    }

    sub setmax_unshared {

        my $class = __PACKAGE__;

        $class->set_max_unshared_size(shift);

        $class->add_cleanup_handler();
    }
}

1;

__END__

=head1 NAME

Apache::SizeLimit - Because size does matter.

=head1 SYNOPSIS

    PerlModule Apache::SizeLimit

    <Perl>
     Apache::SizeLimit->set_max_process_size(150_000);   # Max size in KB
     Apache::SizeLimit->set_min_shared_size(10_000);     # Min share in KB
     Apache::SizeLimit->set_max_unshared_size(120_000);  # Max unshared size in KB
    </Perl>

    PerlCleanupHandler Apache::SizeLimit

=head1 DESCRIPTION

******************************** NOIICE *******************

   This version is only for httpd 1.3.x and mod_perl 1.x
   series.

   For httpd 2.x / mod_perl 2.x Apache2::SizeLimit 
   documentation please read the perldoc in 
   lib/Apache2/SizeLimit.pm

******************************** NOTICE *******************

This module allows you to kill off Apache httpd processes if they grow
too large. You can make the decision to kill a process based on its
overall size, by setting a minimum limit on shared memory, or a
maximum on unshared memory.

You can set limits for each of these sizes, and if any limit is
exceeded, the process will be killed.

You can also limit the frequency that these sizes are checked so that
this module only checks every N requests.

This module is highly platform dependent, please read the
L<PER-PLATFORM BEHAVIOR> section for details. It is possible that this
module simply does not support your platform.

=head1 API

You can set set the size limits from a Perl module or script loaded by
Apache by calling the appropriate class method on C<Apache::SizeLimit>:

=over 4

=item * Apache::SizeLimit->set_max_process_size($size)

This sets the maximum size of the process, including both shared and
unshared memory.

=item * Apache::SizeLimit->set_max_unshared_size($size)

This sets the maximum amount of I<unshared> memory the process can
use.

=item * Apache::SizeLimit->set_min_shared_size($size)

This sets the minimum amount of shared memory the process must have.

=back

The two methods related to shared memory size are effectively a no-op
if the module cannot determine the shared memory size for your
platform. See L<PER-PLATFORM BEHAVIOR> for more details.

=head2 Running the handler()

There are several ways to make this module actually run the code to
kill a process.

The simplest is to make C<Apache::SizeLimit> a C<PerlCleanupHandler>
in your Apache config:

    PerlCleanupHandler Apache::SizeLimit

This will ensure that C<< Apache::SizeLimit->handler() >> is run
for all requests.

If you want to combine this module with a cleanup handler of your own,
make sure that C<Apache::SizeLimit> is the last handler run:

    PerlCleanupHandler  Apache::SizeLimit My::CleanupHandler

Remember, mod_perl will run stacked handlers from right to left, as
they're defined in your configuration.

If you have some cleanup code you need to run, but stacked handlers
aren't appropriate for your setup, you can also explicitly call the
C<< Apache::SizeLimit->handler() >> function from your own cleanup
handler:

    package My::CleanupHandler

    sub handler {
        my $r = shift;

        # Causes File::Temp to remove any temp dirs created during the
        # request
        File::Temp::cleanup();

        return Apache::SizeLimit->handler($r);
    }

=over 4

=item * Apache::SizeLimit->add_cleanup_handler($r)

You can call this method inside a request to run
C<Apache::SizeLimit>'s C<handler()> method for just that request. It's
safe to call this method repeatedly -- the cleanup will only be run
once per request.

=back

=head2 Checking Every N Requests

Since checking the process size can take a few system calls on some
platforms (e.g. linux), you may not want to check the process size for
every request.

=over 4

=item * Apache::SizeLimit->set_check_interval($interval)

Calling this causes C<Apache::SizeLimit> to only check the process
size every C<$interval> requests. If you want this to affect all
processes, make sure to call this during server startup.

=back

=head1 SHARED MEMORY OPTIONS

In addition to simply checking the total size of a process, this
module can factor in how much of the memory used by the process is
actually being shared by copy-on-write. If you don't understand how
memory is shared in this way, take a look at the mod_perl docs at
http://perl.apache.org/docs/.

You can take advantage of the shared memory information by setting a
minimum shared size and/or a maximum unshared size. Experience on one
heavily trafficked mod_perl site showed that setting maximum unshared
size and leaving the others unset is the most effective policy. This
is because it only kills off processes that are truly using too much
physical RAM, allowing most processes to live longer and reducing the
process churn rate.

=head1 PER-PLATFORM BEHAVIOR

This module is highly platform dependent, since finding the size of a
process is different for each OS, and some platforms may not be
supported. In particular, the limits on minimum shared memory and
maximum shared memory are currently only supported on Linux and BSD.
If you can contribute support for another OS, patches are very
welcome.

Currently supported OSes:

=head2 linux

For linux we read the process size out of F</proc/self/statm>. If you
are worried about performance, you can consider using C<<
Apache::SizeLimit->set_check_interval() >> to reduce how often this
read happens.

As of linux 2.6, F</proc/self/statm> does not report the amount of
memory shared by the copy-on-write mechanism as shared memory. This
means that decisions made based on shared memory as reported by that
interface are inherently wrong.

However, as of the 2.6.14 release of the kernel, there is
F</proc/self/smaps> entry for each process. F</proc/self/smaps>
reports various sizes for each memory segment of a process and allows
us to count the amount of shared memory correctly.

If C<Apache::SizeLimit> detects a kernel that supports
F</proc/self/smaps> and the C<Linux::Smaps> module is installed it
will use that module instead of F</proc/self/statm>.

Reading F</proc/self/smaps> is expensive compared to
F</proc/self/statm>. It must look at each page table entry of a
process.  Further, on multiprocessor systems the access is
synchronized with spinlocks. Again, you might consider using C<<
Apache::SizeLimit->set_check_interval() >>.

=head3 Copy-on-write and Shared Memory

The following example shows the effect of copy-on-write:

  <Perl>
    require Apache::SizeLimit;
    package X;
    use strict;
    use Apache::Constants qw(OK);

    my $x = "a" x (1024*1024);

    sub handler {
      my $r = shift;
      my ($size, $shared) = $Apache::SizeLimit->_check_size();
      $x =~ tr/a/b/;
      my ($size2, $shared2) = $Apache::SizeLimit->_check_size();
      $r->content_type('text/plain');
      $r->print("1: size=$size shared=$shared\n");
      $r->print("2: size=$size2 shared=$shared2\n");
      return OK;
    }
  </Perl>

  <Location /X>
    SetHandler modperl
    PerlResponseHandler X
  </Location>

The parent Apache process allocates memory for the string in
C<$x>. The C<tr>-command then overwrites all "a" with "b" if the
handler is called with an argument. This write is done in place, thus,
the process size doesn't change. Only C<$x> is not shared anymore by
means of copy-on-write between the parent and the child.

If F</proc/self/smaps> is available curl shows:

  r2@s93:~/work/mp2> curl http://localhost:8181/X
  1: size=13452 shared=7456
  2: size=13452 shared=6432

Shared memory has lost 1024 kB. The process' overall size remains unchanged.

Without F</proc/self/smaps> it says:

  r2@s93:~/work/mp2> curl http://localhost:8181/X
  1: size=13052 shared=3628
  2: size=13052 shared=3636

One can see the kernel lies about the shared memory. It simply doesn't
count copy-on-write pages as shared.

=head2 solaris 2.6 and above

For solaris we simply retrieve the size of F</proc/self/as>, which
contains the address-space image of the process, and convert to KB.
Shared memory calculations are not supported.

NOTE: This is only known to work for solaris 2.6 and above. Evidently
the F</proc> filesystem has changed between 2.5.1 and 2.6. Can anyone
confirm or deny?

=head2 BSD (and OSX)

Uses C<BSD::Resource::getrusage()> to determine process size.  This is
pretty efficient (a lot more efficient than reading it from the
F</proc> fs anyway).

According to recent tests on OSX (July, 2006), C<BSD::Resource> simply
reports zero for process and shared size on that platform, so OSX is
not supported by C<Apache::SizeLimit>.

=head2 AIX?

Uses C<BSD::Resource::getrusage()> to determine process size.  Not
sure if the shared memory calculations will work or not.  AIX users?

=head2 Win32

Uses C<Win32::API> to access process memory information.
C<Win32::API> can be installed under ActiveState perl using the
supplied ppm utility.

=head2 Everything Else

If your platform is not supported, then please send a patch to check
the process size. The more portable/efficient/correct the solution the
better, of course.

=head1 ABOUT THIS MODULE

This module was written in response to questions on the mod_perl
mailing list on how to tell the httpd process to exit if it gets too
big.

Actually, there are two big reasons your httpd children will grow.
First, your code could have a bug that causes the process to increase
in size very quickly. Second, you could just be doing operations that
require a lot of memory for each request. Since Perl does not give
memory back to the system after using it, the process size can grow
quite large.

This module will not really help you with the first problem. For that
you should probably look into C<Apache::Resource> or some other means
of setting a limit on the data size of your program.  BSD-ish systems
have C<setrlimit()>, which will kill your memory gobbling processes.
However, it is a little violent, terminating your process in
mid-request.

This module attempts to solve the second situation, where your process
slowly grows over time. It checks memory usage after every request,
and if it exceeds a threshold, exits gracefully.

By using this module, you should be able to discontinue using the
Apache configuration directive B<MaxRequestsPerChild>, although for
some folks, using both in combination does the job.

=head1 DEPRECATED APIS

Previous versions of this module documented three globals for defining
memory size limits:

=over 4

=item * $Apache::SizeLimit::MAX_PROCESS_SIZE

=item * $Apache::SizeLimit::MIN_SHARE_SIZE

=item * $Apache::SizeLimit::MAX_UNSHARED_SIZE

=item * $Apache::SizeLimit::CHECK_EVERY_N_REQUESTS

=item * $Apache::SizeLimit::USE_SMAPS

=back

Direct use of these globals is deprecated, but will continue to work
for the foreseeable future.

It also documented three functions for use from registry scripts:

=over 4

=item * Apache::SizeLimit::setmax()

=item * Apache::SizeLimit::setmin()

=item * Apache::SizeLimit::setmax_unshared()

=back

Besides setting the appropriate limit, these functions I<also> add a
cleanup handler to the current request.

=head1 SUPPORT

The Apache-SizeLimit project is co-maintained by several developers,
who take turns at making CPAN releases. Therefore you may find several
CPAN directories containing Apache-SizeLimit releases. The best way to
find the latest release is to use http://search.cpan.org/.

If you have a question or you want to submit a bug report or make a
contribution, please do not email individual authors, but send an
email to the modperl <at> perl.apache.org mailing list. This list is
moderated, so unless you are subscribed to it, your message will have
to be approved first by a moderator. Therefore please allow some time
(up to a few days) for your post to propagate to the list.

=head1 AUTHOR

Doug Bagley <doug+modperl@bagley.org>, channeling Procrustes.

Brian Moseley <ix@maz.org>: Solaris 2.6 support

Doug Steinwand and Perrin Harkins <perrin@elem.com>: added support for
shared memory and additional diagnostic info

Matt Phillips <mphillips@virage.com> and Mohamed Hendawi
<mhendawi@virage.com>: Win32 support

Dave Rolsky <autarch@urth.org>, maintenance and fixes outside of
mod_perl tree (0.9+).

=cut
