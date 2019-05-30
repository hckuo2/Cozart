# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
# XXX: exit should work by stopping the script, but not quitting the
# interpreter, though it's not trivial to make an automated test since
# what you really want to check whether the process didn't quit after
# exit was called. Things become more complicated with
# ithreads-enabled perls where one process may have many interpreters
# and you can't really track those at the moment. So this test needs
# more work.

print "Content-type: text/plain\n\n";

print "before exit";

exit;

print "after exit";


