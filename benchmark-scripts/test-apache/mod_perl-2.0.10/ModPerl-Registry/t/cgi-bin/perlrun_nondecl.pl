# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
# we use this file to test how the files w/o package declaration,
# required from perlrun, work

use Apache::TestUtil;

my $num;

# this BEGIN block is called on every request, since this file gets
# removed from %INC after it was loaded
BEGIN {
    # use an external package which will persist across requests
    $MyData::blocks{BEGIN}{perlrun_nondecl}++;
}

use subs qw(warn_exp);

# all subs in this file get 'redefined' warning because they are
# reloaded in the main:: package, which is not under PerlRun's
# control.

BEGIN {
    t_server_log_warn_is_expected()
        if defined *{"nondecl_no_proto"}{CODE};
}
# normal sub, no prototype
sub nondecl_no_proto        { 1 }

BEGIN {
    t_server_log_warn_is_expected()
        if defined *{"nondecl_proto"}{CODE};
}
# sub with a scalar proto
sub nondecl_proto       ($) { $num = shift }

BEGIN {
    t_server_log_warn_is_expected()
        if defined *{"nondecl_proto_empty"}{CODE};
}
# sub with an empty proto, but not a constant
sub nondecl_proto_empty ()  { $num + 1 }

# besides the the constant sub will generate two warnings for nondecl_const:
# - one for main::
# - another for perlrun's virtual package
BEGIN {
    t_server_log_warn_is_expected(2);
}
# a constant.
sub nondecl_const       ()  { 4 }

END {
    $MyData::blocks{END}{perlrun_nondecl}++;
}

1;
