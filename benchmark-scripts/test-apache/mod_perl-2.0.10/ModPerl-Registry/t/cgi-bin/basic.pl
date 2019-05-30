#!perl -w
# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

# test all the basic functionality

print "Content-type: text/plain\n\n";

# test that __END__ can appear in a comment w/o cutting data after it

print "ok $0";

# test that __END__ starting at the beginning of the line makes
# everything following it, stripped
__END__

this is some irrelevant data
