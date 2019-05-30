# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
# test env vars

print "Content-type: text/plain\n\n";
my $var = $ENV{QUERY_STRING};
print exists $ENV{$var} && $ENV{$var};

__END__
