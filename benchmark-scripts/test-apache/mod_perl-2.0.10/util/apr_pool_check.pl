#!/usr/bin/perl -w
# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-

#check which apr_ functions do not have access to a pool

use lib qw(lib);

use strict;
use Apache2::SourceTables ();

my($functions, @nopool);

#incomplete types (C::Scan only scans *.h, not *.c) we know have an apr_pool_t
my %private = map { $_, 1 } qw{
apr_dir_t apr_file_t apr_dso_handle_t apr_hash_t apr_hash_index_t apr_lock_t
apr_socket_t apr_pollfd_t apr_threadattr_t apr_thread_t apr_threadkey_t
apr_procattr_t apr_xlate_t apr_dbm_t apr_xml_parser
};

for my $entry (@$Apache2::FunctionTable) {
    next unless $entry->{name} =~ /^apr_/;

    $functions++;

    unless (grep { find_pool($_->{type}) } @{ $entry->{args} }) {
        push @nopool, $entry;
    }
}

my $num_nopool = @nopool;

print "$num_nopool functions (out of $functions) do not have access to a pool:\n\n";

for my $entry (@nopool) {
    print "$entry->{return_type} $entry->{name}(",
      (join ', ', map "$_->{type} $_->{name}", @{ $entry->{args} }),
        ")\n\n";
}

sub find_pool {
    my $type = shift;

    return 1 if $type =~ /^apr_pool_t/;

    $type =~ s/\s+\*+$//;
    $type =~ s/^(const|struct)\s+//g;

    if (my $elts = $Apache2::StructureTable{$type}) {
        return 1 if $private{$type};

        for my $e (@$elts) {
            next if $e->{type} =~ /^$type/;
            return 1 if find_pool($e->{type});
        }
    }
}
