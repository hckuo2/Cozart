#!perl -w
# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

# test BEGIN/END blocks

use Apache2::RequestRec ();

use vars qw($query);
$query = '' unless defined $query;

BEGIN {
    $query = $ENV{QUERY_STRING};
}

print "Content-type: text/plain\n\n";

my $r = shift;
our $test = $r->args || '';

if ($test eq 'uncache') {
    # mark the script as non-cached for the next execution
    require ModPerl::RegistryCooker;
    ModPerl::RegistryCooker::uncache_myself();
}
elsif ($test eq 'begin') {
    print "begin ok" if $query eq 'begin';
    # reset the global
    $query = '';
}

END {
    if (defined $test && $test eq 'end') {
        print "end ok";
    }
}
