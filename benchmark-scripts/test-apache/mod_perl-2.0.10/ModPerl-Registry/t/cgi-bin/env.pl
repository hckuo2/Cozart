# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
# test env vars

print "Content-type: text/plain\n\n";
print exists $ENV{QUERY_STRING} && $ENV{QUERY_STRING};

__END__
