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
package ModPerl::Code;

use strict;
use warnings FATAL => 'all';

use Config;
use File::Spec::Functions qw(catfile catdir);

use mod_perl2 ();
use Apache2::Build ();

use Apache::TestConfig ();
use Apache::TestTrace;

our $VERSION = '0.01';
our @ISA = qw(Apache2::Build);

my %handlers = (
    Process    => [qw(ChildInit ChildExit)], #Restart PreConfig
    Files      => [qw(OpenLogs PostConfig)],
    PerSrv     => [qw(PostReadRequest Trans MapToStorage)],
    PerDir     => [qw(HeaderParser
                      Access Authen Authz
                      Type Fixup Response Log Cleanup
                      InputFilter OutputFilter)],
    Connection => [qw(ProcessConnection)],
    PreConnection => [qw(PreConnection)],
);

my %hooks = map { $_, canon_lc($_) }
    map { @{ $handlers{$_} } } keys %handlers;

my %not_ap_hook = map { $_, 1 } qw(child_exit response cleanup
                                   output_filter input_filter);

my %not_request_hook = map { $_, 1 } qw(child_init process_connection
                                        pre_connection open_logs post_config);

my %hook_proto = (
    Process    => {
        ret  => 'void',
        args => [{type => 'apr_pool_t', name => 'p'},
                 {type => 'server_rec', name => 's'},
                 {type => 'dummy', name => 'MP_HOOK_VOID'}],
    },
    Files      => {
        ret  => 'int',
        args => [{type => 'apr_pool_t', name => 'pconf'},
                 {type => 'apr_pool_t', name => 'plog'},
                 {type => 'apr_pool_t', name => 'ptemp'},
                 {type => 'server_rec', name => 's'},
                 {type => 'dummy', name => 'MP_HOOK_RUN_ALL'}],
    },
    PerSrv     => {
        ret  => 'int',
        args => [{type => 'request_rec', name => 'r'},
                 {type => 'dummy', name => 'MP_HOOK_RUN_ALL'}],
    },
    Connection => {
        ret  => 'int',
        args => [{type => 'conn_rec', name => 'c'},
                 {type => 'dummy', name => 'MP_HOOK_RUN_FIRST'}],
    },
    PreConnection => {
        ret  => 'int',
        args => [{type => 'conn_rec', name => 'c'},
                 {type => 'void', name => 'csd'},
                 {type => 'dummy', name => 'MP_HOOK_RUN_ALL'}],
    },
);

my %cmd_push = (
    InputFilter  => 'modperl_cmd_push_filter_handlers',
    OutputFilter => 'modperl_cmd_push_filter_handlers',
);
my $cmd_push_default = 'modperl_cmd_push_handlers';
sub cmd_push {
    $cmd_push{+shift} || $cmd_push_default;
}

$hook_proto{PerDir} = $hook_proto{PerSrv};

my $scfg_get = 'MP_dSCFG(parms->server)';

my $dcfg_get = "$scfg_get;\n" .
  '    modperl_config_dir_t *dcfg = (modperl_config_dir_t *)dummy';

my %directive_proto = (
    PerSrv     => {
        args => [{type => 'cmd_parms', name => 'parms'},
                 {type => 'void', name => 'dummy'},
                 {type => 'const char', name => 'arg'}],
        cfg  => {get => $scfg_get, name => 'scfg'},
        scope => 'RSRC_CONF',
    },
    PerDir     => {
        args => [{type => 'cmd_parms', name => 'parms'},
                 {type => 'void', name => 'dummy'},
                 {type => 'const char', name => 'arg'}],
        cfg  => {get => $dcfg_get, name => 'dcfg'},
        scope => 'OR_ALL',
    },
);

for my $class (qw(Process Connection PreConnection Files)) {
    $directive_proto{$class}->{cfg}->{name} = 'scfg';
    $directive_proto{$class}->{cfg}->{get} = $scfg_get;

    for (qw(args scope)) {
        $directive_proto{$class}->{$_} = $directive_proto{PerSrv}->{$_};
    }
}

while (my ($k,$v) = each %directive_proto) {
    $directive_proto{$k}->{ret} = 'const char *';
    my $handlers = join '_', 'handlers', canon_lc($k);
    $directive_proto{$k}->{handlers} =
      join '->', $directive_proto{$k}->{cfg}->{name}, $handlers;
}

#XXX: allow disabling of PerDir hooks on a PerDir basis
my @hook_flags = sort(map { canon_uc($_) } keys %hooks);
my @ithread_opts = qw(CLONE PARENT);
my %flags = (
    Srv => ['NONE', @ithread_opts, qw(ENABLE AUTOLOAD MERGE_HANDLERS),
            @hook_flags, 'UNSET','INHERIT_SWITCHES'],
    Dir => [qw(NONE PARSE_HEADERS SETUP_ENV MERGE_HANDLERS GLOBAL_REQUEST UNSET)],
    Req => [qw(NONE SET_GLOBAL_REQUEST PARSE_HEADERS SETUP_ENV
               CLEANUP_REGISTERED PERL_SET_ENV_DIR PERL_SET_ENV_SRV)],
    Interp => [qw(NONE IN_USE CLONED BASE)],
    Handler => [qw(NONE PARSED METHOD OBJECT ANON AUTOLOAD DYNAMIC FAKE)],
);

$flags{DirSeen} = $flags{Dir};

my %flags_options = map { $_,1 } qw(Srv Dir);

my %flags_field = (
    DirSeen => 'flags->opts_seen',
    (map { $_, 'flags->opts' } keys %flags_options),
);

sub new {
    my $class = shift;
    bless {
       handlers        => \%handlers,
       hook_proto      => \%hook_proto,
       directive_proto => \%directive_proto,
       flags           => \%flags,
       path            => 'src/modules/perl',
    }, $class;
}

sub path { shift->{path} }

sub handler_desc {
    my ($self, $h_add, $c_add) = @_;
    local $" = ",\n";
    foreach my $class (sort keys %{ $self->{handler_index_desc} }) {
        my $h = $self->{handler_index_desc}->{$class};
        my $func = canon_func('handler', 'desc', $class);
        my $array = join '_', 'MP', $func;
        my $proto = "const char *$func(int idx)";

        $$h_add .= "$proto;\n";

        $$c_add .= <<EOF;
static const char * $array [] = {
@{ [ map { $_ ? qq(    "$_") : '    NULL' } @$h, '' ] }
};

$proto
{
    return $array [idx];
}

EOF
    }
}

sub generate_handler_index {
    my ($self, $h_fh) = @_;

    my $type = 1;

    foreach my $class (sort keys %{ $self->{handlers} }) {
        my $handlers = $self->{handlers}->{$class};
        my $i = 0;
        my $n = @$handlers;
        my $handler_type = canon_define('HANDLER_TYPE', $class);

        print $h_fh "\n#define ",
          canon_define('HANDLER_NUM', $class), " $n\n\n";

        print $h_fh "#define $handler_type $type\n\n";

        $type++;

        for my $name (@$handlers) {
            my $define = canon_define($name, 'handler');
            $self->{handler_index}->{$class}->[$i] = $define;
            $self->{handler_index_type}->{$class}->[$i] = $handler_type;
            $self->{handler_index_desc}->{$class}->[$i] = "Perl${name}Handler";
            print $h_fh "#define $define $i\n";
            $i++;
        }
    }
}

sub generate_handler_hooks {
    my ($self, $h_fh, $c_fh) = @_;

    my @register_hooks;

    foreach my $class (sort keys %{ $self->{hook_proto} }) {
        my $prototype = $self->{hook_proto}->{$class};
        my $callback = canon_func('callback', $class);
        my $return = $prototype->{ret} eq 'void' ? '' : 'return';
        my $i = -1;

        for my $handler (@{ $self->{handlers}{$class} }) {
            my $name = canon_func($handler, 'handler');
            $i++;

            if (my $hook = $hooks{$handler}) {
                next if $not_ap_hook{$hook};

                my $order = $not_request_hook{$hook} ? 'APR_HOOK_FIRST'
                                                     : 'APR_HOOK_REALLY_FIRST';

                push @register_hooks,
                  "    ap_hook_$hook($name, NULL, NULL, $order);";
            }

            my ($protostr, $pass) = canon_proto($prototype, $name);
            my $ix = $self->{handler_index}->{$class}->[$i];

            if ($callback =~ m/modperl_callback_per_(dir|srv)/) {
                if ($ix =~ m/AUTH|TYPE|TRANS|MAP/) {
                    $pass =~ s/MP_HOOK_RUN_ALL/MP_HOOK_RUN_FIRST/;
                }
            }

            print $h_fh "\n$protostr;\n";

            print $c_fh <<EOF;
$protostr
{
    $return $callback($ix, $pass);
}

EOF
        }
    }

    local $" = "\n";
    my $hooks_proto = 'void modperl_register_handler_hooks(void)';
    my $h_add = "$hooks_proto;\n";
    my $c_add = "$hooks_proto {\n@register_hooks\n}\n";

    $self->handler_desc(\$h_add, \$c_add);

    return ($h_add, $c_add);
}

sub generate_handler_find {
    my ($self, $h_fh, $c_fh) = @_;

    my $proto = 'int modperl_handler_lookup(const char *name, int *type)';
    my (%ix, %switch);

    print $h_fh "$proto;\n";

    print $c_fh <<EOF;
$proto
{
    if (*name == 'P' && strnEQ(name, "Perl", 4)) {
        name += 4;
    }

    switch (*name) {
EOF

    foreach my $class (sort keys %{ $self->{handlers} }) {
        my $handlers = $self->{handlers}->{$class};
        my $i = 0;

        for my $name (@$handlers) {
            $name =~ /^([A-Z])/;
            push @{ $switch{$1} }, $name;
            $ix{$name}->{name} = $self->{handler_index}->{$class}->[$i];
            $ix{$name}->{type} = $self->{handler_index_type}->{$class}->[$i++];
        }
    }

    for my $key (sort keys %switch) {
        my $names = $switch{$key};
        print $c_fh "      case '$key':\n";

        #support $r->push_handlers(PerlHandler => ...)
        if ($key eq 'H') {
            print $c_fh <<EOF;
          if (strEQ(name, "Handler")) {
              *type = $ix{'Response'}->{type};
              return $ix{'Response'}->{name};
          }
EOF
        }

        for my $name (@$names) {
            my $n = length($name);
            print $c_fh <<EOF;
          if (strnEQ(name, "$name", $n)) {
              *type = $ix{$name}->{type};
              return $ix{$name}->{name};
          }
EOF
        }
    }

    print $c_fh "    };\n    return -1;\n}\n";

    return ("", "");
}

sub generate_handler_directives {
    my ($self, $h_fh, $c_fh) = @_;

    my @cmd_entries;

    foreach my $class (sort keys %{ $self->{handlers} }) {
        my $handlers = $self->{handlers}->{$class};
        my $prototype = $self->{directive_proto}->{$class};
        my $i = 0;

        for my $h (@$handlers) {
            my $h_name = join $h, qw(Perl Handler);
            my $name = canon_func('cmd', $h, 'handlers');
            my $cmd_name = canon_define('cmd', $h, 'entry');
            my $protostr = canon_proto($prototype, $name);
            my $flag = 'MpSrv' . canon_uc($h);
            my $ix = $self->{handler_index}->{$class}->[$i++];
            my $av = "$prototype->{handlers} [$ix]";
            my $cmd_push = cmd_push($h);

            print $h_fh "$protostr;\n";

            push @cmd_entries, $cmd_name;

            print $h_fh <<EOF;

#define $cmd_name \\
AP_INIT_ITERATE("$h_name", $name, NULL, \\
 $prototype->{scope}, "Subroutine name")

EOF
            print $c_fh <<EOF;

$protostr
{
    $prototype->{cfg}->{get};
    if (!MpSrvENABLE(scfg)) {
        return apr_pstrcat(parms->pool,
                           "Perl is disabled for server ",
                           parms->server->server_hostname, NULL);
    }
    if (!$flag(scfg)) {
        return apr_pstrcat(parms->pool,
                           "$h_name is disabled for server ",
                           parms->server->server_hostname, NULL);
    }
    MP_TRACE_d(MP_FUNC, "push \@%s, %s", parms->cmd->name, arg);
    return $cmd_push(&($av), arg, parms->pool);
}
EOF
        }
    }

    my $h_add =  '#define MP_CMD_ENTRIES \\' . "\n" . join ', \\'."\n", @cmd_entries;

    return ($h_add, "");
}

sub generate_flags {
    my ($self, $h_fh, $c_fh) = @_;

    my $n = 1;

    (my $dlsrc = uc $Config{dlsrc}) =~ s/\.xs$//i;

    print $h_fh "\n#define MP_SYS_$dlsrc 1\n";

    foreach my $class (sort keys %{ $self->{flags} }) {
        my $opts = $self->{flags}->{$class};
        my @lookup = ();
        my %lookup = ();
        my $lookup_proto = "";
        my %dumper;
        if ($flags_options{$class}) {
            $lookup_proto = join canon_func('flags', 'lookup', $class),
              'U32 ', '(const char *str)';
            push @lookup, "$lookup_proto {";
        }

        my $flags = join $class, qw(Mp FLAGS);
        my $field = $flags_field{$class} || 'flags';

        print $h_fh "\n#define $flags(p) (p)->$field\n";

        $class = "Mp$class";
        print $h_fh "\n#define ${class}Type $n\n";
        $n++;

        my $i = 0;
        my $max_len = 0;
        for my $f (@$opts) {
            my $x = sprintf "0x%08x", $i;
            my $flag = "${class}_f_$f";
            my $cmd  = $class . $f;
            my $name = canon_name($f);
            $lookup{$name} = $flag;
            $max_len = length $name if $max_len < length $name;
            print $h_fh <<EOF;

/* $f */
#define $flag $x
#define $cmd(p)  ($flags(p) & $flag)
#define ${cmd}_On(p)  ($flags(p) |= $flag)
#define ${cmd}_Off(p) ($flags(p) &= ~$flag)

EOF
            $dumper{$name} =
              qq{modperl_trace(NULL, " $name %s", \\
                         ($flags(p) & $x) ? "On " : "Off");};

            $i += $i || 1;
        }
        if (@lookup) {
            my $indent1 = " " x 4;
            my $indent2 = " " x 8;
            my %switch = ();
            for (sort keys %lookup) {
                if (/^(\w)/) {
                    my $gap = " " x ($max_len - length $_);
                    push @{ $switch{$1} },
                        qq{if (strEQ(str, "$_"))$gap return $lookup{$_};};
                }
            }

            push @lookup, '', $indent1 . "switch (*str) {";
            for (sort keys %switch) {
                push @lookup, $indent1 . "  case '$_':";
                push @lookup, map { $indent2 . $_ } @{ $switch{$_} };
            }
            push @lookup, map { $indent1 . $_ } ("}\n", "return -1;\n}\n\n");

            print $c_fh join "\n", @lookup;
            print $h_fh "$lookup_proto;\n";
        }

        delete $dumper{None}; #NONE
        print $h_fh join ' \\'."\n",
          "#define ${class}_dump_flags(p, str)",
                     qq{modperl_trace(NULL, "$class flags dump (%s):", str);},
                     map $dumper{$_}, sort keys %dumper;
    }

    print $h_fh "\n#define MpSrvHOOKS_ALL_On(p) MpSrvFLAGS(p) |= (",
      (join '|', map { 'MpSrv_f_' . $_ } @hook_flags), ")\n";

    print $h_fh "\n#define MpSrvOPT_ITHREAD_ONLY(o) \\\n",
      (join ' || ', map("(o == MpSrv_f_$_)", @ithread_opts)), "\n";

    ();
}

my %trace = (
    'a' => 'Apache API interaction',
    'c' => 'configuration for directive handlers',
    'd' => 'directive processing',
    'e' => 'environment variables',
    'f' => 'filters',
    'g' => 'globals management',
    'h' => 'handlers',
    'i' => 'interpreter pool management',
    'm' => 'memory allocations',
    'o' => 'I/O',
    'r' => 'Perl runtime interaction',
    's' => 'Perl sections',
    't' => 'benchmark-ish timings',
);

sub generate_trace {
    my ($self, $h_fh) = @_;

    my $v     = $self->{build}->{VERSION};
    my $api_v = $self->{build}->{API_VERSION};

    print $h_fh qq(#define MP_VERSION_STRING "mod_perl/$v"\n);

    # this needs to be a string, not an int, because of the
    # macro definition.  patches welcome.
    print $h_fh qq(#define MP_API_VERSION "$api_v"\n);

    my $i = 1;
    my @trace = sort keys %trace;
    my $opts = join '', @trace;
    my $tl = "MP_debug_level";

    print $h_fh <<EOF;
#define MP_TRACE_OPTS "$opts"

#ifdef MP_TRACE
#define MP_TRACE_any if ($tl) modperl_trace
#define MP_TRACE_any_do(exp) if ($tl) { \\
exp; \\
}
#else
#define MP_TRACE_any if (0) modperl_trace
#define MP_TRACE_any_do(exp)
#endif

EOF

    my @dumper;
    for my $type (sort @trace) {
        my $define = "#define MP_TRACE_$type";
        my $define_do = join '_', $define, 'do';

        print $h_fh <<EOF;
#ifdef MP_TRACE
$define if ($tl & $i) modperl_trace
$define_do(exp) if ($tl & $i) { \\
exp; \\
}
#else
$define if (0) modperl_trace
$define_do(exp)
#endif
EOF
        push @dumper,
          qq{modperl_trace(NULL, " $type %s ($trace{$type})", ($tl & $i) ? "On " : "Off");};
        $i += $i;
    }

    print $h_fh join ' \\'."\n",
                     '#define MP_TRACE_dump_flags()',
                     qq{modperl_trace(NULL, "mod_perl trace flags dump:");},
                     @dumper;

    ();
}

sub generate_largefiles {
    my ($self, $h_fh) = @_;

    my $flags = $self->perl_config('ccflags_uselargefiles');

    return unless $flags;

    for my $flag (split /\s+/, $flags) {
        next if $flag =~ /^-/; # skip -foo flags
        my ($name, $val) = split '=', $flag;
        $val ||= '';
        $name =~ s/^-D//;
        print $h_fh "#define $name $val\n";
    }
}

sub ins_underscore {
    $_[0] =~ s/([a-z])([A-Z])/$1_$2/g;
    $_[0] =~ s/::/_/g;
}

sub canon_uc {
    my $s = shift;
    ins_underscore($s);
    uc $s;
}

sub canon_lc {
    my $s = shift;
    ins_underscore($s);
    lc $s;
}

sub canon_func {
    join '_', 'modperl', map { canon_lc($_) } @_;
}

sub canon_name {
    local $_ = shift;
    s/([A-Z]+)/ucfirst(lc($1))/ge;
    s/_//g;
    $_;
}

sub canon_define {
    join '_', 'MP', map { canon_uc($_) } @_;
}

sub canon_args {
    my $args = shift->{args};
    my @pass = map { $_->{name} } @$args;
    my @in;
    foreach my $href (@$args) {
        push @in, "$href->{type} *$href->{name}"
            unless $href->{type} eq 'dummy';
    }
    return wantarray ? (\@in, \@pass) : \@in;
}

sub canon_proto {
    my ($prototype, $name) = @_;
    my ($in,$pass) = canon_args($prototype);

    local $" = ', ';

    my $p = "$prototype->{ret} $name(@$in)";
    $p =~ s/\* /*/;
    return wantarray ? ($p, "@$pass") : $p;
}

my %sources = (
   generate_handler_index      => {h => 'modperl_hooks.h'},
   generate_handler_hooks      => {h => 'modperl_hooks.h',
                                   c => 'modperl_hooks.c'},
   generate_handler_directives => {h => 'modperl_directives.h',
                                   c => 'modperl_directives.c'},
   generate_handler_find       => {h => 'modperl_hooks.h',
                                   c => 'modperl_hooks.c'},
   generate_flags              => {h => 'modperl_flags.h',
                                   c => 'modperl_flags.c'},
   generate_trace              => {h => 'modperl_trace.h'},
   generate_largefiles         => {h => 'modperl_largefiles.h'},
   generate_constants          => {h => 'modperl_constants.h',
                                   c => 'modperl_constants.c'},
   generate_exports            => {c => 'modperl_exports.c'},
);

my @c_src_names = qw(interp tipool log config cmd options callback handler
                     gtop util io io_apache filter bucket mgv pcw global env
                     cgi perl perl_global perl_pp sys module svptr_table
                     const constants apache_compat error debug
                     common_util common_log);
my @h_src_names = qw(perl_unembed);
my @g_c_names = map { "modperl_$_" } qw(hooks directives flags xsinit exports);
my @c_names   = ('mod_perl', (map "modperl_$_", @c_src_names));
sub c_files { [map { "$_.c" } @c_names, @g_c_names] }
sub o_files { [map { "$_.o" } @c_names, @g_c_names] }
sub o_pic_files { [map { "$_.lo" } @c_names, @g_c_names] }

my @g_h_names = map { "modperl_$_" } qw(hooks directives flags trace
                                        largefiles);
my @h_names = (@c_names, map { "modperl_$_" } @h_src_names,
               qw(types time apache_includes perl_includes apr_includes
                  apr_compat common_includes common_types));
sub h_files { [map { "$_.h" } @h_names, @g_h_names] }

sub clean_files {
    my @c_names = @g_c_names;
    my @h_names = @g_h_names;

    for (\@c_names, \@h_names) {
        push @$_, 'modperl_constants';
    }

    [(map { "$_.c" } @c_names), (map { "$_.h" } @h_names)];
}

sub classname {
    my $self = shift || __PACKAGE__;
    ref($self) || $self;
}

sub noedit_warning_c {
    my $class = classname(shift);

    my $v = join '/', $class, $class->VERSION;
    my $trace = Apache::TestConfig::calls_trace();
    $trace =~ s/^/ * /mg;
    return <<EOF;

/*
 * *********** WARNING **************
 * This file generated by $v
 * Any changes made here will be lost
 * ***********************************
$trace */

EOF
}

#this is named hash after the `#' character
#rather than named perl, since #comments are used
#non-Perl files, e.g. Makefile, typemap, etc.
sub noedit_warning_hash {
    my $class = classname(shift);

    (my $warning = noedit_warning_c($class)) =~ s/^/\# /mg;
    return $warning;
}

sub init_file {
    my ($self, $name) = @_;

    return unless $name;
    return if $self->{init_files}->{$name}++;

    my (@preamble);
    if ($name =~ /\.h$/) {
        (my $d = uc $name) =~ s/\./_/;
        push @preamble, "#ifndef $d\n#define $d\n";
        push @{ $self->{postamble}->{$name} }, "\n#endif /* $d */\n";
    }
    elsif ($name =~ /\.c/) {
        push @preamble, qq{\#include "mod_perl.h"\n\n};
    }

    my $file = "$self->{path}/$name";
    debug "generating...$file";
    unlink $file;
    open my $fh, '>>', $file or die "open $file: $!";
    print $fh @preamble, noedit_warning_c();

    $self->{fh}->{$name} = $fh;
}

sub fh {
    my ($self, $name) = @_;
    return unless $name;
    $self->{fh}->{$name};
}

sub postamble {
    my $self = shift;
    for my $name (sort keys %{ $self->{fh} }) {
        next unless my $av = $self->{postamble}->{$name};
        print { $self->fh($name) } @$av;
    }
}

sub generate {
    my ($self, $build) = @_;

    $self->{build} = $build;

    for my $s (values %sources) {
        for (qw(h c)) {
            $self->init_file($s->{$_});
        }
    }

    for my $method (reverse sort keys %sources) {
        my ($h_fh, $c_fh) = map {
            $self->fh($sources{$method}->{$_});
        } qw(h c);
        my ($h_add, $c_add) = $self->$method($h_fh, $c_fh);
        if ($h_add) {
            print $h_fh $h_add;
        }
        if ($c_add) {
            print $c_fh $c_add;
        }
        debug "$method...done";
    }

    $self->postamble;

    my $xsinit = "$self->{path}/modperl_xsinit.c";
    debug "generating...$xsinit";

    # There's a possibility that $Config{static_ext} may contain spaces
    # and ExtUtils::Embed::xsinit won't handle the situation right. In
    # this case we'll get buggy "boot_" statements in modperl_xsinit.c.
    # Fix this by cleaning the @Extensions array.

    # Loads @Extensions if not loaded
    ExtUtils::Embed::static_ext();

    @ExtUtils::Embed::Extensions = grep{$_} @ExtUtils::Embed::Extensions;

    #create bootstrap method for static xs modules
    my $static_xs = [sort keys %{ $build->{XS} }];
    ExtUtils::Embed::xsinit($xsinit, 1, $static_xs);

    #$self->generate_constants_pod();
}

my $constant_prefixes = join '|', qw{APR? MODPERL_RC};

sub generate_constants {
    my ($self, $h_fh, $c_fh) = @_;

    require Apache2::ConstantsTable;

    print $c_fh qq{\#include "modperl_const.h"\n};
    print $h_fh "#define MP_ENOCONST -3\n\n";

    generate_constants_lookup($h_fh, $c_fh);
    generate_constants_group_lookup($h_fh, $c_fh);
}

my %shortcuts = (
     NOT_FOUND => 'HTTP_NOT_FOUND',
     FORBIDDEN => 'HTTP_FORBIDDEN',
     AUTH_REQUIRED => 'HTTP_UNAUTHORIZED',
     SERVER_ERROR => 'HTTP_INTERNAL_SERVER_ERROR',
     REDIRECT => 'HTTP_MOVED_TEMPORARILY',
);

#backwards compat with older httpd/apr
#XXX: remove once we require newer httpd/apr
my %ifdef = map { $_, 1 }
    qw(APLOG_TOCLIENT APR_LIMIT_NOFILE), # added in ???
    qw(AP_MPMQ_STARTING AP_MPMQ_RUNNING AP_MPMQ_STOPPING
       AP_MPMQ_MPM_STATE), # added in 2.0.49
    qw(APR_FPROT_USETID APR_FPROT_GSETID
       APR_FPROT_WSTICKY APR_FOPEN_LARGEFILE), # added in 2.0.50?
    qw(OPT_INCNOEXEC OPT_INC_WITH_EXEC); # added/removed in 2.4

sub constants_ifdef {
    my $name = shift;

    if ($ifdef{$name}) {
        return ("#ifdef $name\n", "#endif /* $name */\n");
    }

    ("", "");
}

sub constants_lookup_code {
    my ($h_fh, $c_fh, $constants, $class) = @_;

    my (%switch, %alias);

    %alias = %shortcuts;

    my $postfix = canon_lc(lc $class);
    my $package = $class . '::';
    my $package_len = length $package;
    my ($first_let) = $class =~ /^(\w)/;

    my $func = canon_func(qw(constants lookup), $postfix);
    my $proto = "SV \*$func(pTHX_ const char *name)";

    print $h_fh "$proto;\n";

    print $c_fh <<EOF;

$proto
{
    if (*name == '$first_let' && strnEQ(name, "$package", $package_len)) {
        name += $package_len;
    }

    switch (*name) {
EOF

    for (@$constants) {
        if (s/^($constant_prefixes)(_)?//o) {
            $alias{$_} = join $2 || "", $1, $_;
        }
        else {
            $alias{$_} ||= $_;
        }
        next unless /^([A-Z])/;
        push @{ $switch{$1} }, $_;
    }

    for my $key (sort keys %switch) {
        my $names = $switch{$key};
        print $c_fh "      case '$key':\n";

        for my $name (@$names) {
            my @ifdef = constants_ifdef($alias{$name});
            print $c_fh <<EOF;
$ifdef[0]
          if (strEQ(name, "$name")) {
EOF

            if ($name eq 'DECLINE_CMD' ||
                $name eq 'DIR_MAGIC_TYPE' ||
                $name eq 'CRLF' ||
                $name eq 'AUTHN_PROVIDER_GROUP' ||
                $name eq 'AUTHZ_PROVIDER_GROUP' ||
                $name eq 'AUTHN_PROVIDER_VERSION' ||
                $name eq 'AUTHZ_PROVIDER_VERSION' ||
                $name eq 'AUTHN_DEFAULT_PROVIDER' ||
                $name eq 'AUTHN_PROVIDER_NAME_NOTE' ||
                $name eq 'AUTHZ_PROVIDER_NAME_NOTE' ||
                $name eq 'AUTHN_PREFIX' ||
                $name eq 'AUTHZ_PREFIX' ||
                $name eq 'CRLF_ASCII') {
                print $c_fh <<EOF;
              return newSVpv($alias{$name}, 0);
EOF
            }
            else {
                print $c_fh <<EOF;
              return newSViv($alias{$name});
EOF
            }

            print $c_fh <<EOF;
          }
$ifdef[1]
EOF
        }
        print $c_fh "      break;\n";
    }

    print $c_fh <<EOF
    };
    Perl_croak(aTHX_ "unknown $class\:: constant %s", name);
    return newSViv(MP_ENOCONST);
}
EOF
}

sub generate_constants_lookup {
    my ($h_fh, $c_fh) = @_;

    foreach my $class (sort keys %$Apache2::ConstantsTable) {
        my $groups = $Apache2::ConstantsTable->{$class};
        my $constants = [sort map { @$_ } values %$groups];

        constants_lookup_code($h_fh, $c_fh, $constants, $class);
    }
}

sub generate_constants_group_lookup {
    my ($h_fh, $c_fh) = @_;

    foreach my $class (sort keys %$Apache2::ConstantsTable) {
        my $groups = $Apache2::ConstantsTable->{$class};
        constants_group_lookup_code($h_fh, $c_fh, $class, $groups);
    }
}

sub constants_group_lookup_code {
    my ($h_fh, $c_fh, $class, $groups) = @_;
    my @tags;
    my @code;

    $class = canon_lc(lc $class);
    foreach my $group (sort keys %$groups) {
        my $constants = $groups->{$group};
        push @tags, $group;
        my $name = join '_', 'MP_constants', $class, $group;
        print $c_fh "\nstatic const char *$name [] = { \n",
          (map {
              my @ifdef = constants_ifdef($_);
              s/^($constant_prefixes)_?//o;
              qq($ifdef[0]   "$_",\n$ifdef[1])
          } @$constants), "   NULL,\n};\n";
    }

    my %switch;
    for (@tags) {
        next unless /^([A-Z])/i;
        push @{ $switch{$1} }, $_;
    }

    my $func = canon_func(qw(constants group lookup), $class);

    my $proto = "const char **$func(const char *name)";

    print $h_fh "$proto;\n";
    print $c_fh "\n$proto\n{\n", "   switch (*name) {\n";

    for my $key (sort keys %switch) {
        my $val = $switch{$key};
        print $c_fh "\tcase '$key':\n";
        for my $group (@$val) {
            my $name = join '_', 'MP_constants', $class, $group;
            print $c_fh qq|\tif(strEQ("$group", name))\n\t   return $name;\n|;
        }
        print $c_fh "      break;\n";
    }

    print $c_fh <<EOF;
    };
    Perl_croak_nocontext("unknown $class\:: group `%s'", name);
    return NULL;
}
EOF
}

my %seen_const = ();
# generates APR::Const and Apache2::Const manpages in ./tmp/
sub generate_constants_pod {
    my ($self) = @_;

    my %data = ();
    generate_constants_group_lookup_doc(\%data);
    generate_constants_lookup_doc(\%data);

    # XXX: may be dump %data into ModPerl::MethodLookup and provide an
    # easy api to map const groups to constants and vice versa

    require File::Path;
    my $file = "Const.pod";
    for my $class (sort keys %data) {
        my $path = catdir "tmp", $class;
        File::Path::mkpath($path, 0, 0755);
        my $filepath = catfile $path, $file;
        open my $fh, ">$filepath" or die "Can't open $filepath: $!\n";

        print $fh <<"EOF";
=head1 NAME

$class\::Const - Perl Interface for $class Constants

=head1 SYNOPSIS

=head1 CONSTANTS

EOF

        my $groups = $data{$class};
        for my $group (sort keys %$groups) {
            print $fh <<"EOF";



=head2 C<:$group>

  use $class\::Const -compile qw(:$group);

The C<:$group> group is for XXX constants.

EOF

            for my $const (sort @{ $groups->{$group} }) {
                print $fh "=head3 C<$class\::$const>\n\n\n";
            }
        }

        print $fh "=cut\n";
    }
}

sub generate_constants_lookup_doc {
    my ($data) = @_;

    foreach my $class (sort keys %$Apache2::ConstantsTable) {
        my $groups = $Apache2::ConstantsTable->{$class};
        my $constants = [sort map { @$_ } values %$groups];

        constants_lookup_code_doc($constants, $class, $data);
    }
}

sub generate_constants_group_lookup_doc {
    my ($data) = @_;

    foreach my $class (sort keys %$Apache2::ConstantsTable) {
        my $groups = $Apache2::ConstantsTable->{$class};
        constants_group_lookup_code_doc($class, $groups, $data);
    }
}

sub constants_group_lookup_code_doc {
    my ($class, $groups, $data) = @_;
    my @tags;
    my @code;

    while (my ($group, $constants) = each %$groups) {
        $data->{$class}{$group} = [
            map {
                my @ifdef = constants_ifdef($_);
                s/^($constant_prefixes)_?//o;
                $seen_const{$class}{$_}++;
                $_;
            } @$constants
        ];
    }
}

sub constants_lookup_code_doc {
    my ($constants, $class, $data) = @_;

    my (%switch, %alias);

    %alias = %shortcuts;

    my $postfix = lc $class;
    my $package = $class . '::';
    my $package_len = length $package;

    my $func = canon_func(qw(constants lookup), $postfix);

    for (@$constants) {
        if (s/^($constant_prefixes)(_)?//o) {
            $alias{$_} = join $2 || "", $1, $_;
        }
        else {
            $alias{$_} ||= $_;
        }
        next unless /^([A-Z])/;
        push @{ $switch{$1} }, $_;
    }

    for my $key (sort keys %switch) {
        my $names = $switch{$key};
        for my $name (@$names) {
            my @ifdef = constants_ifdef($alias{$name});
            push @{ $data->{$class}{other} }, $name
                unless $seen_const{$class}{$name}
        }
    }
}

sub generate_exports {
    my ($self, $c_fh) = @_;
    require ModPerl::WrapXS;
    ModPerl::WrapXS->generate_exports($c_fh);
}

# src/modules/perl/*.c files needed to build APR/APR::* outside
# of mod_perl.so
sub src_apr_ext {
    return map { "modperl_$_" } (qw(error bucket),
                                  map { "common_$_" } qw(util log));
}

1;
__END__

=head1 NAME

ModPerl::Code - Generate mod_perl glue code

=head1 SYNOPSIS

  use ModPerl::Code ();
  my $code = ModPerl::Code->new;
  $code->generate;

=head1 DESCRIPTION

This module provides functionality for generating mod_perl glue code.
Reason this code is generated rather than written by hand include:

=over 4

=item consistency

=item thin and clean glue code

=item enable/disable features (without #ifdefs)

=item adapt to changes in Apache

=item experiment with different approaches to gluing

=back

=head1 AUTHOR

Doug MacEachern

=cut
