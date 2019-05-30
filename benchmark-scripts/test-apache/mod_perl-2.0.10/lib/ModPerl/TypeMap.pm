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
package ModPerl::TypeMap;

use strict;
use warnings FATAL => 'all';

use ModPerl::FunctionMap ();
use ModPerl::StructureMap ();
use ModPerl::MapUtil qw(list_first);

our @ISA = qw(ModPerl::MapBase);

sub new {
    my $class = shift;

    my $self = bless {
        INCLUDE => [],
        struct  => [],
        typedef => [],
    }, $class;

    $self->{function_map}  = ModPerl::FunctionMap->new,
    $self->{structure_map} = ModPerl::StructureMap->new,

    $self->get;
    $self;
}

my %special = map { $_, 1 } qw(UNDEFINED NOTIMPL CALLBACK);

sub special {
    my ($self, $class) = @_;
    return $special{$class};
}

sub function_map  { shift->{function_map}->get  }
sub structure_map { shift->{structure_map}->get }

sub parse {
    my ($self, $fh, $map) = @_;

    while ($fh->readline) {
        if (/E=/) {
            my %args = $self->parse_keywords($_);
            while (my ($key,$val) = each %args) {
                push @{ $self->{$key} }, $val;
            }
            next;
        }

        my @aliases;
        my ($type, $class) = (split /\s*\|\s*/, $_)[0,1];
        $class ||= 'UNDEFINED';

        if ($type =~ s/^(struct|typedef)\s+(.*)/$2/) {
            my $typemap = $1;
            push @aliases, $type;

            if ($typemap eq 'struct') {
                push @aliases, "const $type", "$type *", "const $type *",
                  "struct $type *", "const struct $type *",
                  "$type **";
            }

            my $cname = $class;
            if ($cname =~ s/::/__/g) {
                push @{ $self->{$typemap} }, [$type, $cname];
            }
        }
        elsif ($type =~ /_t$/) {
            push @aliases, $type, "$type *", "const $type *";
        }
        else {
            push @aliases, $type;
        }

        for (@aliases) {
            $map->{$_} = $class;
        }
    }
}

sub get {
    my $self = shift;

    $self->{map} ||= $self->parse_map_files;
}

my $ignore = join '|', qw{
ap_LINK ap_HOOK _ UINT union._
union.block_hdr cleanup process_chain
iovec struct.rlimit Sigfunc in_addr_t
};

sub should_ignore {
    my ($self, $type) = @_;
    return 1 if $type =~ /^($ignore)/o;
}

sub is_callback {
    my ($self, $type) = @_;
    return 1 if $type =~ /\(/ and $type =~ /\)/; #XXX: callback
}

sub exists {
    my ($self, $type) = @_;

    return 1 if $self->is_callback($type) || $self->should_ignore($type);

    $type =~ s/\[\d+\]$//; #char foo[64]

    return exists $self->get->{$type};
}

sub map_type {
    my ($self, $type) = @_;
    my $class = $self->get->{$type};

    return unless $class and ! $self->special($class);
#    return if $type =~ /\*\*$/; #XXX
    if ($class =~ /::/) {
        return $class;
    }
    else {
        return $type;
    }
}

sub null_type {
    my ($self, $type) = @_;
    my $class = $self->get->{$type};

    if ($class =~ /^[INU]V/) {
        return '0';
    }
    else {
        return 'NULL';
    }
}

sub can_map {
    my $self = shift;
    my $map = shift;

    return 1 if $map->{argspec};

    for (@_) {
        return (0, $_) unless $self->map_type($_);
    }

    return 1;
}

sub map_arg {
    my ($self, $arg) = @_;

    my $map_type = $self->map_type($arg->{type});
    die "unknown typemap: '$arg->{type}'" unless defined $map_type;

    return {
       name    => $arg->{name},
       default => $arg->{default},
       type    => $map_type,
       rtype   => $arg->{type},
    }
}

sub map_args {
    my ($self, $func) = @_;

    my $entry = $self->function_map->{ $func->{name} };
    my $argspec = $entry->{argspec};
    my $args = [];

    if ($argspec) {
        $entry->{orig_args} = [ map $_->{name}, @{ $func->{args} } ];

        for my $arg (@$argspec) {
            my $default;
            ($arg, $default) = split /=/, $arg, 2;
            my ($type, $name) = split ':', $arg, 2;

            if ($type and $name) {
                push @$args, {
                   name => $name,
                   type => $type,
                   default => $default,
                };
            }
            else {
                my $e = list_first { $_->{name} eq $arg } @{ $func->{args} };
                if ($e) {
                    push @$args, { %$e, default => $default };
                }
                elsif ($arg eq '...') {
                    push @$args, { name => '...', type => 'SV *' };
                }
                else {
                    warn "bad argspec: $func->{name} ($arg)\n";
                }
            }
        }
    }
    else {
        $args = $func->{args};
    }

    return [ map $self->map_arg($_), @$args ]
}

#this is needed for modperl-only functions
#unlike apache/apr functions which are remapped to a mpxs_ function
sub thx_fixup {
    my ($self, $func) = @_;

    my $first = $func->{args}->[0];

    return unless $first;

    if ($first->{type} =~ /PerlInterpreter/) {
        shift @{ $func->{args} };
        $func->{thx} = 1;
    }
}

sub map_function {
    my ($self, $func) = @_;

    my $map = $self->function_map->{ $func->{name} };
    return unless $map;

    $self->thx_fixup($func);

    my ($status, $failed_type) =
        $self->can_map($map, $func->{return_type},
            map $_->{type}, @{ $func->{args} });

    unless ($status) {
        warn "unknown typemap: '$failed_type' (skipping $func->{name})\n";
        return;
    }

    my $type = $map->{return_type} || $func->{return_type} || 'void';
    my $map_type = $self->map_type($type);
    die "unknown typemap: '$type'" unless defined $map_type;

    my $mf = {
       name        => $func->{name},
       return_type => $map_type,
       args        => $self->map_args($func),
       perl_name   => $map->{name},
       thx         => $func->{thx},
    };

    for (qw(dispatch argspec orig_args prefix)) {
        $mf->{$_} = $map->{$_};
    }

    unless ($mf->{class}) {
        $mf->{class} = $map->{class} || $self->first_class($mf);
        #print "GUESS class=$mf->{class} for $mf->{name}\n";
    }

    $mf->{prefix} ||= ModPerl::FunctionMap::guess_prefix($mf);

    $mf->{module} = $map->{module} || $mf->{class};

    $mf;
}

sub map_structure {
    my ($self, $struct) = @_;

    my ($class, @elts);
    my $stype = $struct->{type};

    return unless $class = $self->map_type($stype);

    for my $e (@{ $struct->{elts} }) {
        my ($name, $type) = ($e->{name}, $e->{type});
        my $rtype;

        # ro/rw/r+w_startup/undef(disabled)
        my $access_mode = $self->structure_map->{$stype}->{$name};
        next unless $access_mode;
        next unless $rtype = $self->map_type($type);

        push @elts, {
           name        => $name,
           type        => $rtype,
           default     => $self->null_type($type),
           pool        => $self->class_pool($class),
           class       => $self->{map}->{$type} || "",
           access_mode => $access_mode,
        };
    }

    return {
       module => $self->{structure_map}->{MODULES}->{$stype} || $class,
       class  => $class,
       type   => $stype,
       elts   => \@elts,
    };
}

sub destructor {
    my ($self, $prefix) = @_;
    $self->function_map->{$prefix . 'DESTROY'};
}

sub first_class {
    my ($self, $func) = @_;

    for my $e (@{ $func->{args} }) {
        next unless $e->{type} =~ /::/;
        #there are alot of util functions that take an APR::Pool
        #that do not belong in the APR::Pool class
        next if $e->{type} eq 'APR::Pool' and $func->{name} !~ /^apr_pool/;
        return $e->{type};
    }

    return $func->{name} =~ /^apr_/ ? 'APR' : 'Apache2';
}

sub check {
    my $self = shift;

    my (@types, @missing, %seen);

    require Apache2::StructureTable;
    for my $entry (@$Apache2::StructureTable) {
        push @types, map $_->{type}, @{ $entry->{elts} };
    }

    for my $entry (@$Apache2::FunctionTable) {
        push @types, grep { not $seen{$_}++ }
          ($entry->{return_type},
           map $_->{type}, @{ $entry->{args} })
    }

    #printf "%d types\n", scalar @types;

    for my $type (@types) {
        push @missing, $type unless $self->exists($type);
    }

    return @missing ? \@missing : undef;
}

#look for Apache/APR structures that do not exist in structure.map
my %ignore_check = map { $_,1 } qw{
module_struct cmd_how kill_conditions
regex_t regmatch_t pthread_mutex_t
unsigned void va_list ... iovec char int long const
gid_t uid_t time_t pid_t size_t
sockaddr hostent
SV
};

sub check_exists {
    my $self = shift;

    my %structures = map { $_->{type}, 1 } @{ $self->structure_table() };
    my @missing = ();
    my %seen;

    for my $name (keys %{ $self->{map} }) {
        1 while $name =~ s/^\w+\s+(\w+)/$1/;
        $name =~ s/\s+\**.*$//;
        next if $seen{$name}++ or $structures{$name} or $ignore_check{$name};
        push @missing, $name;
    }

    return @missing ? \@missing : undef;
}

#XXX: generate this
my %class_pools = map {
    (my $f = "mpxs_${_}_pool") =~ s/:/_/g;
    $_, $f;
} qw{
     Apache2::RequestRec Apache2::Connection Apache2::URI APR::URI
};

sub class_pool : lvalue {
    my ($self, $class) = @_;
    $class_pools{$class};
}

#anything needed that mod_perl.h does not already include
#XXX: .maps should INCLUDE= these
my @includes = qw{
apr_uuid.h
apr_sha1.h
apr_md5.h
apr_base64.h
apr_getopt.h
apr_hash.h
apr_lib.h
apr_general.h
apr_signal.h
apr_thread_rwlock.h
util_script.h
};

sub h_wrap {
    my ($self, $file, $code) = @_;

    $file = 'modperl_xs_' . $file;

    my $h_def = uc "${file}_h";
    my $preamble = "\#ifndef $h_def\n\#define $h_def\n\n";
    my $postamble = "\n\#endif /* $h_def */\n";

    return ("$file.h", $preamble . $code . $postamble);
}

sub typedefs_code {
    my $self = shift;
    my $map = $self->get;
    my %seen;

    my $file = 'modperl_xs_typedefs';
    my $h_def = uc "${file}_h";
    my $code = "";

    for (@includes, @{ $self->{INCLUDE} }) {
        $code .= qq{\#include "$_"\n}
    }

    for my $t (sort {$a->[1] cmp $b->[1]} @{ $self->{struct} }) {
        next if $seen{ $t->[1] }++;
        $code .= "typedef $t->[0] * $t->[1];\n";
    }

    for my $t (sort {$a->[1] cmp $b->[1]} @{ $self->{typedef} }) {
        next if $seen{ $t->[1] }++;
        $code .= "typedef $t->[0] $t->[1];\n";
    }

    $self->h_wrap('typedefs', $code);
}

my %convert_alias = (
    Apache2__RequestRec => 'r',
    Apache2__Server => 'server',
    Apache2__Connection => 'connection',
    APR__Table => 'table',
    APR__UUID => 'uuid',
    apr_status_t => 'status',
);

sub sv_convert_code {
    my $self = shift;
    my $map = $self->get;
    my %seen;
    my $code = "";

    for my $ctype (sort keys %$map) {
        my $ptype = $map->{$ctype};

        next if $self->special($ptype);
        next if $ctype =~ /\s/;
        my $class = $ptype;

        if ($ptype =~ s/:/_/g) {
            next if $seen{$ptype}++;

            my $alias;
            my $expect = "expecting an $class derived object";
            my $croak  = "argument is not a blessed reference";

            #Perl -> C
            my $define = "mp_xs_sv2_$ptype";

            $code .= <<EOF;
#define $define(sv) \\
((SvROK(sv) && (SvTYPE(SvRV(sv)) == SVt_PVMG)) \\
|| (Perl_croak(aTHX_ "$croak ($expect)"),0) ? \\
INT2PTR($ctype *, SvIV((SV*)SvRV(sv))) : ($ctype *)NULL)

EOF

            if ($alias = $convert_alias{$ptype}) {
                $code .= "#define mp_xs_sv2_$alias $define\n\n";
            }

            #C -> Perl
            $define = "mp_xs_${ptype}_2obj";

            $code .= <<EOF;
#define $define(ptr) \\
sv_setref_pv(sv_newmortal(), "$class", (void*)ptr)

EOF

            if ($alias) {
                $code .= "#define mp_xs_${alias}_2obj $define\n\n";
            }
        }
        else {
            if ($ptype =~ /^(\wV)$/) {
                my $class = $1;
                my $define = "mp_xs_sv2_$ctype";

                $code .= "#define $define(sv) ($ctype)Sv$class(sv)\n\n";

                if (my $alias = $convert_alias{$ctype}) {
                    $code .= "#define mp_xs_sv2_$alias $define\n\n";
                }
            }
        }
    }

    $self->h_wrap('sv_convert', $code);
}

1;
__END__
