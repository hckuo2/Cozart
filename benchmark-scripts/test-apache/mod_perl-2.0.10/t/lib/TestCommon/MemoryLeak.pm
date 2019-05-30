# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestCommon::MemoryLeak;

# handy functions to measure memory leaks. since it measures the total
# memory size of the process and not just perl leaks, you get your
# C/XS leaks discovered too
#
# For example to test TestAPR::Pool::handler for leaks, add to its
# top:
#
#  TestCommon::MemoryLeak::start();
#
# and just before returning from the handler add:
#
#  TestCommon::MemoryLeak::end();
#
# now start the server with only worker server
#
#  % t/TEST -maxclients 1 -start
#
# of course use maxclients 1 only if your test be handled with one
# client, e.g. proxy tests need at least two clients.
#
# Now repeat the same test several times (more than 3)
#
# % t/TEST -run apr/pool -times=10
#
# t/logs/error_log will include something like:
#
#    size    vsize resident    share      rss
#    196k     132k     196k       0M     196k
#    104k     132k     104k       0M     104k
#     16k       0k      16k       0k      16k
#      0k       0k       0k       0k       0k
#      0k       0k       0k       0k       0k
#      0k       0k       0k       0k       0k
#
# as you can see the first few runs were allocating memory, but the
# following runs should consume no more memory. The leak tester measures
# the extra memory allocated by the process since the last test. Notice
# that perl and apr pools usually allocate more memory than they
# need, so some leaks can be hard to see, unless many tests (like a
# hundred) were run.

use strict;
use warnings FATAL => 'all';

# XXX: as of 5.8.4 when spawning ithreads we get an annoying
#  Attempt to free unreferenced scalar ... perlbug #24660
# because of $gtop's CLONE'd object, so pretend that we have no gtop
# for now if perl is threaded
# GTop v0.12 is the first version that will work under threaded mpms
use Config;
use constant HAS_GTOP => eval { !$Config{useithreads} &&
                                require GTop && GTop->VERSION >= 0.12 };

my $gtop = HAS_GTOP ? GTop->new : undef;
my @attrs = qw(size vsize resident share rss);
my $format = "%8s %8s %8s %8s %8s\n";

my %before;

sub start {

    die "No GTop avaible, bailing out" unless HAS_GTOP;

    unless (keys %before) {
        my $before = $gtop->proc_mem($$);
        %before = map { $_ => $before->$_() } @attrs;
        # print the header once
        warn sprintf $format, @attrs;
    }
}

sub end {

    die "No GTop avaible, bailing out" unless HAS_GTOP;

    my $after = $gtop->proc_mem($$);
    my %after = map {$_ => $after->$_()} @attrs;
    warn sprintf $format,
        map GTop::size_string($after{$_} - $before{$_}), @attrs;
    %before = %after;
}

1;

__END__
