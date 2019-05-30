# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
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
#
package Apache2::ParseSource;

use strict;
use warnings FATAL => 'all';

use Apache2::Build ();
use Config;
use File::Basename;
use File::Spec::Functions qw(catdir);

our $VERSION = '0.02';

sub new {
    my $class = shift;

    my $self = bless {
        config => Apache2::Build->build_config,
        @_,
    }, $class;

    my $prefixes = join '|', @{ $self->{prefixes} || [qw(ap_ apr_)] };
    $self->{prefix_re} = qr{^($prefixes)};

    $Apache2::Build::APXS ||= $self->{apxs};

    $self;
}

sub config {
    shift->{config};
}

sub parse {
    my $self = shift;

    $self->{scan_filename} = $self->generate_cscan_file;

    $self->{c} = $self->scan;
}

sub DESTROY {
    my $self = shift;
    unlink $self->{scan_filename}
}

{
    package Apache2::ParseSource::Scan;

    our @ISA = qw(ModPerl::CScan);

    sub get {
        local $SIG{__DIE__} = \&Carp::confess;
        shift->SUPER::get(@_);
    }
}

my @c_scan_defines = (
    'CORE_PRIVATE',   #so we get all of apache
    'MP_SOURCE_SCAN', #so we can avoid some c-scan barfing
    '_NETINET_TCP_H', #c-scan chokes on netinet/tcp.h
    '_BYTESWAP_H', #c-scan chokes on byteswap.h
    '_BITS_BYTESWAP_H', #c-scan chokes on byteswap.h
    'Expat_INCLUDED', #c-scan chokes on expath.h
 #   'APR_OPTIONAL_H', #c-scan chokes on apr_optional.h
    'apr_table_do_callback_fn_t=void', #c-scan chokes on function pointers
);


# some types c-scan failing to resolve
push @c_scan_defines, map { "$_=void" }
    qw(PPADDR_t PerlExitListEntry modperl_tipool_vtbl_t);

sub scan {
    require ModPerl::CScan;
    ModPerl::CScan->VERSION(0.75);
    require Carp;

    my $self = shift;

    my $c = ModPerl::CScan->new(filename => $self->{scan_filename});

    my $includes = $self->includes;

    # where to find perl headers, but we don't want to parse them otherwise
    my $perl_core_path = catdir $Config{installarchlib}, "CORE";
    push @$includes, $perl_core_path;

    $c->set(includeDirs => $includes);

    my @defines = @c_scan_defines;

    unless ($Config{useithreads} and $Config{useithreads} eq 'define') {
        #fake -DITHREADS so function tables are the same for
        #vanilla and ithread perls, that is,
        #make sure THX and friends are always expanded
        push @defines, 'MP_SOURCE_SCAN_NEED_ITHREADS';
    }

    $c->set(Defines => join ' ', map "-D$_", @defines);

    bless $c, 'Apache2::ParseSource::Scan';
}

sub include_dirs {
    my $self = shift;
    my $inc = $self->config->apxs('-q' => 'INCLUDEDIR');
    my @dirs = ($inc, $self->config->mp_include_dir);
    my $aprinc = $self->config->apxs('-q' => 'APR_INCLUDEDIR');

    unless ($aprinc eq $inc) {
        # Add APR include directory if different to httpd includedir
        push @dirs, $aprinc;
    }

    @dirs;
}

sub includes { shift->config->includes }

sub find_includes {
    my $self = shift;

    return $self->{includes} if $self->{includes};

    require File::Find;

    my @includes = ();
    # don't pick preinstalled mod_perl headers if any, but pick the rest
    {
        my @dirs = $self->include_dirs;
        die "could not find include directory (build the project first)"
            unless -d $dirs[0];

        my $unwanted = join '|', qw(ap_listen internal version
                                    apr_optional mod_include mod_cgi
                                    mod_proxy mod_ssl ssl_ apr_anylock
                                    apr_rmm ap_config mod_log_config
                                    mod_perl modperl_ apreq mod_cache
                                    mod_serf mod_dav);
        $unwanted = qr|^$unwanted|;
        my $wanted = '';

        push @includes, find_includes_wanted($wanted, $unwanted, @dirs);
    }

    # now add the live mod_perl headers (to make sure that we always
    # work against the latest source)
    {
        my @dirs = map { catdir $self->config->{cwd}, $_ }
            catdir(qw(src modules perl)), 'xs';

        my $unwanted = '';
        my $wanted = join '|', qw(mod_perl modperl_);
        $wanted = qr|^$wanted|;

        push @includes, find_includes_wanted($wanted, $unwanted, @dirs);
    }

    # now reorg the header files list, so the fragile scan won't choke
    my @apr = ();
    my @mp = ();
    my @rest = ();
    for (@includes) {
        if (/mod_perl.h$/) {
            # mod_perl.h needs to be included before other mod_perl
            # headers
            unshift @mp, $_;
        }
        elsif (/modperl_\w+.h$/) {
            push @mp, $_;
        }
        elsif (/apr_\w+\.h$/ ) {
            # apr headers need to be included first
            push @apr, $_;
        }
        else {
            push @rest, $_;
        }
    }
    @includes = (@apr, @rest, @mp);

    return $self->{includes} = \@includes;
}

sub find_includes_wanted {
    my ($wanted, $unwanted, @dirs) = @_;
    my @includes = ();
    for my $dir (@dirs) {
        File::Find::finddepth({
                               wanted => sub {
                                   return unless /\.h$/;

                                   if ($wanted) {
                                       return unless /$wanted/;
                                   }
                                   else {
                                       return if /$unwanted/;
                                   }

                                   my $dir = $File::Find::dir;
                                   push @includes, "$dir/$_";
                               },
                               (Apache2::Build::WIN32 ? '' : follow => 1),
                              }, $dir);
    }
    return @includes;
}

sub generate_cscan_file {
    my $self = shift;

    my $includes = $self->find_includes;

    my $filename = '.apache_includes';
    open my $fh, '>', $filename or die "can't open $filename: $!";

    for my $path (@$includes) {
        my $filename = basename $path;
        print $fh qq(\#include "$path"\n);
    }

    close $fh;

    return $filename;
}

my %defines_wanted = (
    'Apache2::Const' => {
        common     => [qw{OK DECLINED DONE}],
        config     => [qw{DECLINE_CMD}],
        context    => [qw(NOT_IN_ GLOBAL_ONLY)],
        http       => [qw{HTTP_}],
        log        => [qw(APLOG_)],
        methods    => [qw{M_ METHODS}],
        mpmq       => [qw{AP_MPMQ_}],
        options    => [qw{OPT_}],
        override   => [qw{OR_ EXEC_ON_READ ACCESS_CONF RSRC_CONF}],
        proxy      => [qw{PROXYREQ_}],
        platform   => [qw{CRLF CR LF}],
        remotehost => [qw{REMOTE_}],
        satisfy    => [qw{SATISFY_}],
        types      => [qw{DIR_MAGIC_TYPE}],
        auth       => [qw{AUTHN_ AUTHZ AP_AUTH_ AUTH_ AUTHZ_}],
    },
    'APR::Const' => {
        common    => [qw{APR_SUCCESS}],
        error     => [qw{APR_E}],
        filepath  => [qw{APR_FILEPATH_}],
        filetype  => [qw{APR_FILETYPE_}],
        fopen     => [qw{APR_FOPEN_}],
        fprot     => [qw{APR_FPROT_}],
        finfo     => [qw{APR_FINFO_}],
        flock     => [qw{APR_FLOCK_}],
        hook      => [qw{APR_HOOK_}],
        limit     => [qw{APR_LIMIT}],
        poll      => [qw{APR_POLL}],
        socket    => [qw{APR_SO_}],
        status    => [qw{APR_TIMEUP}],
        table     => [qw{APR_OVERLAP_TABLES_}],
        uri       => [qw{APR_URI_}],
    },
   ModPerl => {
        common    => [qw{MODPERL_RC_}],
   }
);

my %defines_wanted_re;
while (my ($class, $groups) = each %defines_wanted) {
    while (my ($group, $wanted) = each %$groups) {
        my $pat = join '|', @$wanted;
        $defines_wanted_re{$class}->{$group} = $pat; #qr{^($pat)};
    }
}

my %enums_wanted = (
    'Apache2::Const' => { map { $_, 1 } qw(cmd_how input_mode filter_type conn_keepalive authn_status authz_status) },
    'APR::Const' => { map { $_, 1 } qw(apr_shutdown_how apr_read_type apr_lockmech) },
);

my $defines_unwanted = join '|', qw{
HTTP_VERSION APR_EOL_STR APLOG_MARK APLOG_NOERRNO APR_SO_TIMEOUT
APR_HOOK_PROBES_ENABLED APR_HOOK_INT_DCL_UD
APLOG_MAX_LOGLEVEL
APR_BEGIN_DECLS APR_END_DECLS
};

sub get_constants {
    my ($self) = @_;

    my $includes = $self->find_includes;
    my (%constants, %seen);

    for my $file (@$includes) {
        open my $fh, $file or die "open $file: $!";
        while (<$fh>) {
            if (s/^\#define\s+(\w+)\s+.*/$1/) {
                chomp;
                next if /_H$/;
                next if $seen{$_}++;
                $self->handle_constant(\%constants);
            }
            elsif (m/enum[^\{]+\{/) {
                $self->handle_enum($fh, \%constants);
            }
        }
        close $fh;
    }

    #maintain a few handy shortcuts from 1.xx
    #aliases are defined in ModPerl::Code
    push @{ $constants{'Apache2::Const'}->{common} },
      qw(NOT_FOUND FORBIDDEN AUTH_REQUIRED SERVER_ERROR REDIRECT);

    return \%constants;
}

sub handle_constant {
    my ($self, $constants) = @_;
    my $keys = keys %defines_wanted_re;

    return if /^($defines_unwanted)/o;

    while (my ($class, $groups) = each %defines_wanted_re) {
        my $keys = keys %$groups;

        while (my ($group, $re) = each %$groups) {
            next unless /^($re)/;
            push @{ $constants->{$class}->{$group} }, $_;
            return;
        }
    }
}

sub handle_enum {
    my ($self, $fh, $constants) = @_;

    my ($name, $e) = $self->parse_enum($fh);
    return unless $name;

    $name =~ s/^ap_//;
    $name =~ s/_(e|t)$//;

    my $class;
    for (keys %enums_wanted) {
        next unless $enums_wanted{$_}->{$name};
        $class = $_;
    }

    return unless $class;
    $name =~ s/^apr_//;

    push @{ $constants->{$class}->{$name} }, @$e if $e;
}

#this should win an award for worlds lamest parser
sub parse_enum {
    my ($self, $fh) = @_;
    my $code = $_;
    my @e;

    unless ($code =~ /;\s*$/) {
        local $_;
        while (<$fh>) {
            $code .= $_;
            last if /;\s*$/;
        }
    }

    my $name;
    if ($code =~ s/^\s*enum\s+(\w*)\s*//) {
        $name = $1;
    }
    elsif ($code =~ s/^\s*typedef\s+enum\s+//) {
        $code =~ s/\s*(\w+)\s*;\s*$//;
        $name = $1;
    }

    $code =~ s:/\*.*?\*/::sg;
    $code =~ s/\s*=\s*\w+//g;
    $code =~ s/^[^\{]*\{//s;
    $code =~ s/\}[^;]*;?//s;
    $code =~ s/^\s*\n//gm;

    while ($code =~ /\b(\w+)\b,?/g) {
        push @e, $1;
    }

    return ($name, \@e);
}

sub wanted_functions  { shift->{prefix_re} }
sub wanted_structures { shift->{prefix_re} }

sub get_functions {
    my $self = shift;

    my $key = 'parsed_fdecls';
    return $self->{$key} if $self->{$key};

    my $c = $self->{c};

    my $fdecls = $c->get($key);
    my $inlines = $c->get('parsed_inlines');
    push @{$fdecls}, @{$inlines};

    my %seen;
    my $wanted = $self->wanted_functions;

    my @functions;

    for my $entry (@$fdecls) {
        my ($rtype, $name, $args) = @$entry;
        next unless $name =~ $wanted;
        next if $seen{$name}++;
        my @attr;

        for (qw(static __inline__)) {
            if ($rtype =~ s/^($_)\s+//) {
                push @attr, $1;
            }
        }

        #XXX: working around ModPerl::CScan confusion here
        #macro defines ap_run_error_log causes
        #cpp filename:linenumber to be included as part of the type
        for (@$args) {
            next unless $_->[0];
            $_->[0] =~ s/^\#.*?\"\s+//;
            $_->[0] =~ s/^register //;
        }

        my $func = {
           name => $name,
           return_type => $rtype,
           args => [map {
               { type => $_->[0], name => $_->[1] }
           } @$args],
        };

        $func->{attr} = \@attr if @attr;

        push @functions, $func;
    }

    # sort the functions by the 'name' attribute to ensure a
    # consistent output on different systems.
    $self->{$key} = [sort { $a->{name} cmp $b->{name} } @functions];
}

sub get_structs {
    my $self = shift;

    my $key = 'typedef_structs';
    return $self->{$key} if $self->{$key};

    my $c = $self->{c};

    my $typedef_structs = $c->get($key);

    my %seen;
    my $wanted = $self->wanted_structures;
    my $other  = join '|', qw(_rec module
                              piped_log uri_t htaccess_result
                              cmd_parms cmd_func cmd_how);

    my @structures;
    my $sx = qr(^struct\s+);

    while (my ($type, $elts) = each %$typedef_structs) {
        next unless $type =~ $wanted or $type =~ /($other)$/o;

        $type =~ s/$sx//;

        next if $seen{$type}++;

        my $struct = {
           type => $type,
           elts => [map {
               my $type = $_->[0];
               $type =~ s/$sx//;
               $type .= $_->[1] if $_->[1];
               $type =~ s/:\d+$//; #unsigned:1
               { type => $type, name => $_->[2] }
           } @$elts],
        };

        push @structures, $struct;
    }

    # sort the structs by the 'type' attribute to ensure a consistent
    # output on different systems.
    $self->{$key} = [sort { $a->{type} cmp $b->{type} } @structures];
}

sub write_functions_pm {
    my $self = shift;
    my $file = shift || 'FunctionTable.pm';
    my $name = shift || 'Apache2::FunctionTable';

    $self->write_pm($file, $name, $self->get_functions);
}

sub write_structs_pm {
    my $self = shift;
    my $file = shift || 'StructureTable.pm';
    my $name = shift || 'Apache2::StructureTable';

    $self->write_pm($file, $name, $self->get_structs);
}

sub write_constants_pm {
    my $self = shift;
    my $file = shift || 'ConstantsTable.pm';
    my $name = shift || 'Apache2::ConstantsTable';

    $self->write_pm($file, $name, $self->get_constants);
}

sub write_pm {
    my ($self, $file, $name, $data) = @_;

    require Data::Dumper;
    local $Data::Dumper::Indent = 1;

    my ($subdir) = (split '::', $name)[0];

    my $tdir = '';
    my $build = Apache2::Build->new(init => 1);
    my $httpd_version = $build->httpd_version;
    if ($httpd_version lt '2.4.0') {
        $tdir='xs/tables/current';
    }
    else {
        $tdir='xs/tables/current24';
    }

    if (-d "$tdir/$subdir") {
        $file = "$tdir/$subdir/$file";
    }

    # sort the hashes (including nested ones) for a consistent dump
    canonsort(\$data);

    my $dump = Data::Dumper->new([$data],
                                 [$name])->Dump;

    my $package = ref($self) || $self;
    my $version = $self->VERSION;
    my $date = scalar localtime;

    my $new_content = << "EOF";
package $name;

# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# ! WARNING: generated by $package/$version
# !          $date
# !          do NOT edit, any changes will be lost !
# !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

$dump

1;
EOF

    my $old_content = '';
    if (-e $file) {
        open my $pm, '<', $file or die "open $file: $!";
        local $/ = undef; # slurp the file
        $old_content = <$pm>;
        close $pm;
    }

    my $overwrite = 1;
    if ($old_content) {
        # strip the date line, which will never be the same before
        # comparing
        my $table_header = qr{^\#\s!.*};
        (my $old = $old_content) =~ s/$table_header//mg;
        (my $new = $new_content) =~ s/$table_header//mg;
        $overwrite = 0 if $old eq $new;
    }

    if ($overwrite) {
        open my $pm, '>', $file or die "open $file: $!";
        print $pm $new_content;
        close $pm;
    }

}

# canonsort(\$data);
# sort nested hashes in the data structure.
# the data structure itself gets modified

sub canonsort {
    my $ref = shift;
    my $type = ref $$ref;

    return unless $type;

    require Tie::IxHash;

    my $data = $$ref;

    if ($type eq 'ARRAY') {
        for (@$data) {
            canonsort(\$_);
        }
    }
    elsif ($type eq 'HASH') {
        for (keys %$data) {
            canonsort(\$data->{$_});
        }

        tie my %ixhash, 'Tie::IxHash';

        # reverse sort so we get the order of:
        # return_type, name, args { type, name } for functions
        # type, elts { type, name } for structures

        for (sort { $b cmp $a } keys %$data) {
            $ixhash{$_} = $data->{$_};
        }

        $$ref = \%ixhash;
    }
}

1;
__END__
