#!perl -w
# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

# this test should return forbidden, since it should be not-executable

print "Content-type: text/plain\n\n";
print "ok";

__END__

this is some irrelevant data
