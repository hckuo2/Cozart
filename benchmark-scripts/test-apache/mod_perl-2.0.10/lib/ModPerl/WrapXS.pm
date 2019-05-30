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
package ModPerl::WrapXS;

use strict;
use warnings FATAL => 'all';

use constant GvUNIQUE => 0; #$] >= 5.008;
use Apache::TestTrace;
use Apache2::Build ();
use ModPerl::Code ();
use ModPerl::TypeMap ();
use ModPerl::MapUtil qw(function_table xs_glue_dirs);
use File::Path qw(rmtree mkpath);
use Cwd qw(fastcwd);
use Data::Dumper;
use File::Spec::Functions qw(catfile catdir);

our $VERSION = '0.01';

my (@xs_includes) = ('mod_perl.h',
                    map "modperl_xs_$_.h", qw(sv_convert util typedefs));

my @global_structs = qw(perl_module);

my $build = Apache2::Build->build_config;
push @global_structs, 'MP_debug_level' unless Apache2::Build::WIN32;

sub new {
    my $class = shift;

    my $self = bless {
       typemap   => ModPerl::TypeMap->new,
       includes  => \@xs_includes,
       glue_dirs => [xs_glue_dirs()],
    }, $class;

    $self->typemap->get;
    $self;
}

sub typemap  { shift->{typemap} }

sub includes { shift->{includes} }

sub function_list {
    my $self = shift;
    my (@list) = @{ function_table() };

    while (my ($name, $val) = each %{ $self->typemap->function_map }) {
        #entries that do not exist in C::Scan generated tables
        next unless $name =~ /^DEFINE_/;
        push @list, $val;
    }

    return \@list;
}

sub get_functions {
    my $self = shift;
    my $typemap = $self->typemap;

    for my $entry (sort { $a->{name} cmp $b->{name} } @{ $self->function_list() }) {
        my $func = $typemap->map_function($entry);
        #print "FAILED to map $entry->{name}\n" unless $func;
        next unless $func;

        my ($name, $module, $class, $args) =
          @{ $func } { qw(perl_name module class args) };

        $self->{XS}->{ $module } ||= [];

        #eg ap_fputs()
        if ($name =~ s/^DEFINE_//) {
            $func->{name} =~ s/^DEFINE_//;

            if (needs_prefix($func->{name})) {
                #e.g. DEFINE_add_output_filter
                $func->{name} = make_prefix($func->{name}, $class);
            }
        }

        my $xs_parms = join ', ',
          map { defined $_->{default} ?
                  "$_->{name}=$_->{default}" : $_->{name} } @$args;

        (my $parms = $xs_parms) =~ s/=[^,]+//g; #strip defaults

        my $proto = join "\n",
          (map "    $_->{type} $_->{name}", @$args), "";

        my ($dispatch, $orig_args) =
          @{ $func } {qw(dispatch orig_args)};

        if ($dispatch =~ /^MPXS_/) {
            $name =~ s/^mpxs_//;
            $name =~ s/^$func->{prefix}//;
            push @{ $self->{newXS}->{ $module } },
              ["$class\::$name", $dispatch];
            next;
        }

        my $passthru = @$args && $args->[0]->{name} eq '...';
        if ($passthru) {
            $parms = '...';
            $proto = '';
        }

        my $return_type =
          $name =~ /^DESTROY$/ ? 'void' : $func->{return_type};

        my $attrs = $self->attrs($name);

        my $code = <<EOF;
$return_type
$name($xs_parms)
$proto
$attrs
EOF

        if ($dispatch || $orig_args || $func->{thx}) {
            my $thx = $func->{thx} ? 'aTHX_ ' : "";

            if ($dispatch) {
                $thx = 'aTHX_ ' if $dispatch =~ /^mpxs_/i;
            }
            else {
                if ($orig_args and @$orig_args == @$args) {
                    #args were reordered
                    $parms = join ', ', @$orig_args;
                }

                $dispatch = $func->{name};
            }

            if ($passthru) {
                $thx ||= 'aTHX_ ';
                $parms = 'items, MARK+1, SP';
            }

            $thx =~ s/_ $// unless $parms;

            my $retval = $return_type eq 'void' ?
              ["", ""] : ["RETVAL = ", "OUTPUT:\n    RETVAL\n"];
            
            my $avoid_warning = "";
            if (@$args and not $passthru) {
                $avoid_warning = "    /* avoiding -Wall warnings */\n";
                $avoid_warning .= join "\n",
                    (map "    $_->{name} = $_->{name};", @$args), "";
            }
            $code .= <<EOF;
    CODE:
$avoid_warning
    $retval->[0]$dispatch($thx$parms);

    $retval->[1]
EOF
        }

        $func->{code} = $code;
        push @{ $self->{XS}->{ $module } }, $func;
    }
}

sub get_value {
    my $e = shift;
    my $val = 'val';

    if ($e->{class} eq 'PV') {
        if (my $pool = $e->{pool}) {
            $pool .= '(obj)';
            $val = "(SvOK(ST(1)) ?
                    apr_pstrndup($pool, val, val_len) : NULL)"
        }
    }

    return $val;
}

sub get_structures {
    my $self = shift;
    my $typemap = $self->typemap;

    require Apache2::StructureTable;
    for my $entry (@$Apache2::StructureTable) {
        my $struct = $typemap->map_structure($entry);
        next unless $struct;

        my $class = $struct->{class};

        for my $e (@{ $struct->{elts} }) {
            my ($name, $default, $type, $access_mode) =
              @{$e}{qw(name default type access_mode)};

            (my $cast = $type) =~ s/:/_/g;
            my $val = get_value($e);

            my $type_in = $type;
            my $preinit = "/*nada*/";
            if ($e->{class} eq 'PV' and $val ne 'val') {
                $type_in =~ s/char/char_len/;
                $preinit = "STRLEN val_len;";
            }

            my $attrs = $self->attrs($name);

            my $code;
            if ($access_mode eq 'ro') {
                $code = <<EOF;
$type
$name(obj)
    $class obj

$attrs

    CODE:
    RETVAL = ($cast) obj->$name;

    OUTPUT:
    RETVAL

EOF
            }
            elsif ($access_mode eq 'rw' or $access_mode eq 'r+w_startup') {

                my $check_runtime = $access_mode eq 'rw'
                    ? ''
                    : qq[MP_CROAK_IF_THREADS_STARTED("setting $name");];

                $code = <<EOF;
$type
$name(obj, val=$default)
    $class obj
    $type_in val

    PREINIT:
    $preinit
$attrs

    CODE:
    RETVAL = ($cast) obj->$name;

    if (items > 1) {
         $check_runtime
         obj->$name = ($cast) $val;
    }

    OUTPUT:
    RETVAL

EOF
            }
            elsif ($access_mode eq 'r+w_startup_dup') {

                my $convert = $cast !~ /\bchar\b/
                    ? "mp_xs_sv2_$cast"
                    : "SvPV_nolen";

                $code = <<EOF;
$type
$name(obj, val=(SV *)NULL)
    $class obj
    SV *val

    PREINIT:
    $preinit
$attrs

    CODE:
    RETVAL = ($cast) obj->$name;

    if (items > 1) {
         SV *dup = get_sv("_modperl_private::server_rec_$name", TRUE);
         MP_CROAK_IF_THREADS_STARTED("setting $name");
         sv_setsv(dup, val);
         obj->$name = ($cast)$convert(dup);
    }

    OUTPUT:
    RETVAL

EOF
            }
            elsif ($access_mode eq 'rw_char_undef') {
                my $pool = $e->{pool}
                    or die "rw_char_undef accessors need pool";
                $pool .= '(obj)';
# XXX: not sure where val=$default is coming from, but for now use
# hardcoded (SV *)NULL
                $code = <<EOF;
$type
$name(obj, val_sv=(SV *)NULL)
    $class obj
    SV *val_sv

    PREINIT:
$attrs

    CODE:
    RETVAL = ($cast) obj->$name;

    if (val_sv) {
        if (SvOK(val_sv)) {
            STRLEN val_len;
            char *val = (char *)SvPV(val_sv, val_len);
            obj->$name = apr_pstrndup($pool, val, val_len);
        }
        else {
            obj->$name = NULL;
        }
    }

    OUTPUT:
    RETVAL

EOF
            }

            push @{ $self->{XS}->{ $struct->{module} } }, {
               code  => $code,
               class => $class,
               name  => $name,
            };
        }
    }
}

sub prepare {
    my $self = shift;
    $self->{DIR} = 'WrapXS';
    $self->{XS_DIR} = catdir fastcwd(), 'xs';

    my $verbose = Apache::TestTrace::trace_level() eq 'debug' ? 1 : 0;

    if (-e $self->{DIR}) {
        rmtree([$self->{DIR}], $verbose, 1);
    }

    mkpath [$self->{DIR}], $verbose, 0755;
}

sub class_dirname {
    my ($self, $class) = @_;
    my ($base, $sub) = split '::', $class;
    return "$self->{DIR}/$base" unless $sub; #Apache2 | APR
    return $sub if $sub eq $self->{DIR}; #WrapXS
    return "$base/$sub";
}

sub class_dir {
    my ($self, $class) = @_;

    my $dirname = $self->class_dirname($class);
    my $dir = ($dirname =~ m:/: and $dirname !~ m:^$self->{DIR}:) ?
      catdir($self->{DIR}, $dirname) : $dirname;

    unless (-d $dir) {
        mkpath [$dir], 0, 0755;
        debug "mkdir.....$dir";
    }

    $dir;
}

sub class_file {
    my ($self, $class, $file) = @_;
    catfile $self->class_dir($class), $file;
}

sub cname {
    my ($self, $class) = @_;
    $class =~ s/:/_/g;
    $class;
}

sub open_class_file {
    my ($self, $class, $file) = @_;

    if ($file =~ /^\./) {
        my $sub = (split '::', $class)[-1];
        $file = $sub . $file;
    }

    my $name = $self->class_file($class, $file);

    open my $fh, '>', $name or die "open $name: $!";
    debug "writing...$name";

    return $fh;
}

sub module_version {
    local $_ = shift;
    require mod_perl2;
    # XXX: for now APR gets its libapr-0.9 version
    return /^APR/ ? "0.009000" : "$mod_perl2::VERSION";
}

sub write_makefilepl {
    my ($self, $class) = @_;

    my $fh = $self->open_class_file($class, 'Makefile.PL');

    my $includes = $self->includes;
    my $xs = (split '::', $class)[-1] . '.c';
    my $deps = {$xs => ""};

    if (my $mod_h = $self->mod_h($class, 1)) {
        $deps->{$xs} .= " $mod_h";
    }

    local $Data::Dumper::Terse = 1;
    $deps = Dumper $deps;

    my $noedit_warning = $self->ModPerl::Code::noedit_warning_hash();
    require mod_perl2;
    my $version = module_version($class);

    print $fh <<EOF;
$noedit_warning

use lib qw(../../../lib); #for Apache2::BuildConfig
use ModPerl::BuildMM ();

ModPerl::BuildMM::WriteMakefile(
    'NAME'    => '$class',
    'VERSION' => '$version',
    'depend'  => $deps,
);
EOF

    close $fh;
}

sub mod_h {
    my ($self, $module, $complete) = @_;

    my $dirname = $self->class_dirname($module);
    my $cname = $self->cname($module);
    my $mod_h = "$dirname/$cname.h";

    for ($self->{XS_DIR}, @{ $self->{glue_dirs} }) {
        my $file = "$_/$mod_h";
        $mod_h = $file if $complete;
        return $mod_h if -e $file;
    }

    undef;
}

sub mod_pm {
    my ($self, $module, $complete) = @_;

    my $dirname = $self->class_dirname($module);
    my ($base, $sub) = split '::', $module;
    my $mod_pm = "$dirname/${sub}_pm";

    for ($self->{XS_DIR}, @{ $self->{glue_dirs} }) {
        my $file = "$_/$mod_pm";
        $mod_pm = $file if $complete;
        return $mod_pm if -e $file;
    }

    undef;
}

sub class_c_prefix {
    my $class = shift;
    $class =~ s/:/_/g;
    $class;
}

sub class_mpxs_prefix {
    my $class = shift;
    my $class_prefix = class_c_prefix($class);
    "mpxs_${class_prefix}_";
}

sub needs_prefix {
    my $name = shift;
    $name !~ /^(ap|apr|mpxs)_/i;
}

sub make_prefix {
    my ($name, $class) = @_;
    my $class_prefix = class_mpxs_prefix($class);
    return $name if $name =~ /^$class_prefix/;
    $class_prefix . $name;
}

sub isa_str {
    my ($self, $module) = @_;
    my $str = "";

    if (my $isa = $self->typemap->{function_map}->{isa}->{$module}) {
        foreach my $sub (sort keys %$isa) {
            my $base = $isa->{$sub};
#XXX cannot set isa in the BOOT: section because XSLoader local-ises
#ISA during bootstrap
#            $str .= qq{    av_push(get_av("$sub\::ISA", TRUE),
#                                   newSVpv("$base",0));}
            $str .= qq{\@$sub\::ISA = '$base';\n}
        }
    }

    $str;
}

sub boot {
    my ($self, $module) = @_;
    my $str = "";

    if (my $boot = $self->typemap->{function_map}->{boot}->{$module}) {
        $str = '    mpxs_' . $self->cname($module) . "_BOOT(aTHX);\n";
    }

    $str;
}

my $notshared = join '|', qw(TIEHANDLE); #not sure why yet

sub attrs {
    my ($self, $name) = @_;
    my $str = "";
    return $str if $name =~ /$notshared$/o;
    $str = "    ATTRS: unique\n" if GvUNIQUE;
    $str;
}

sub write_xs {
    my ($self, $module, $functions) = @_;

    my $fh = $self->open_class_file($module, '.xs');
    print $fh $self->ModPerl::Code::noedit_warning_c(), "\n";
    print $fh "\n#define MP_IN_XS\n\n";

    my @includes = @{ $self->includes };

    if (my $mod_h = $self->mod_h($module)) {
        push @includes, $mod_h;
    }

    for (@includes) {
        print $fh qq{\#include "$_"\n\n};
    }

    my $last_prefix = "";

    for my $func (@$functions) {
        my $class = $func->{class};
        my $prefix = $func->{prefix};
        $last_prefix = $prefix if $prefix;

        if ($func->{name} =~ /^mpxs_/) {
            #e.g. mpxs_Apache2__RequestRec_
            my $class_prefix = class_c_prefix($class);
            if ($func->{name} =~ /$class_prefix/) {
                $prefix = class_mpxs_prefix($class);
            }
        }

        $prefix = $prefix ? "  PREFIX = $prefix" : "";
        print $fh "MODULE = $module    PACKAGE = $class $prefix\n\n";

        print $fh $func->{code};
    }

    if (my $destructor = $self->typemap->destructor($last_prefix)) {
        my $arg = $destructor->{argspec}[0];

        print $fh <<EOF;
void
$destructor->{name}($arg)
    $destructor->{class} $arg

EOF
    }

    print $fh "MODULE = $module\n";
    print $fh "PROTOTYPES: disabled\n\n";
    print $fh "BOOT:\n";
    print $fh $self->boot($module);
    print $fh "    items = items; /* -Wall */\n\n";

    if (my $newxs = $self->{newXS}->{$module}) {
        for my $xs (sort { $a->[0] cmp $b->[0] } @$newxs) {
            print $fh qq{   cv = newXS("$xs->[0]", $xs->[1], __FILE__);\n};
            print $fh qq{   GvUNIQUE_on(CvGV(cv));\n} if GvUNIQUE;
        }
    }

    if ($module eq 'APR::Pool' && Apache2::Build::PERL_HAS_ITHREADS) {
        print $fh "    modperl_opt_interp_unselect = APR_RETRIEVE_OPTIONAL_FN(modperl_interp_unselect);\n\n";
        print $fh "    modperl_opt_thx_interp_get  = APR_RETRIEVE_OPTIONAL_FN(modperl_thx_interp_get);\n\n";
    }

    close $fh;
}

sub write_pm {
    my ($self, $module) = @_;

    my $isa = $self->isa_str($module);

    my $code = "";
    if (my $mod_pm = $self->mod_pm($module, 1)) {
        open my $fh, '<', $mod_pm;
        local $/;
        $code = <$fh>;
        close $fh;
    }

    my $base   = (split '::', $module)[0];
    unless (-e "lib/$base/XSLoader.pm") {
        $base = 'Apache2';
    }
    my $loader = join '::', $base, 'XSLoader';

    my $fh = $self->open_class_file($module, '.pm');
    my $noedit_warning = $self->ModPerl::Code::noedit_warning_hash();
    my $use_apr = ($module =~ /^APR::\w+$/) ? 'use APR ();' : '';
    my $version = module_version($module);

    print $fh <<EOF;
$noedit_warning

package $module;

use strict;
use warnings FATAL => 'all';

$isa
$use_apr
use $loader ();
our \$VERSION = '$version';
$loader\::load __PACKAGE__;

$code

1;
__END__
EOF
}

my %typemap = (
    'Apache2::RequestRec' => 'T_APACHEOBJ',
    'apr_time_t'         => 'T_APR_TIME',
    'APR::Table'         => 'T_HASHOBJ',
    'APR::Pool'          => 'T_POOLOBJ',
    'apr_size_t *'       => 'T_UVPTR',
);

sub write_typemap {
    my $self = shift;
    my $typemap = $self->typemap;
    my $map = $typemap->get;
    my %seen;

    my $fh = $self->open_class_file('ModPerl::WrapXS', 'typemap');
    print $fh $self->ModPerl::Code::noedit_warning_hash(), "\n";

    my %entries = ();
    my $max_key_len = 0;
    while (my ($type, $class) = each %$map) {
        $class ||= $type;
        next if $seen{$type}++ || $typemap->special($class);

        if ($class =~ /::/) {
            $entries{$class} = $typemap{$class} || 'T_PTROBJ';
            $max_key_len = length $class if length $class > $max_key_len;
        }
        else {
            $entries{$type} = $typemap{$type} || "T_$class";
            $max_key_len = length $type if length $type > $max_key_len;
        }
    }

    for (sort keys %entries) {
        printf $fh "%-${max_key_len}s %s\n", $_, $entries{$_};
    }

    close $fh;
}

sub write_typemap_h_file {
    my ($self, $method) = @_;

    $method = $method . '_code';
    my ($h, $code) = $self->typemap->$method();
    my $file = catfile $self->{XS_DIR}, $h;

    open my $fh, '>', $file or die "open $file: $!";
    print $fh $self->ModPerl::Code::noedit_warning_c(), "\n";
    print $fh $code;
    close $fh;
}

sub write_lookup_method_file {
    my $self = shift;

    my %map = ();
    foreach my $module (sort keys %{ $self->{XS} }) {
        my $functions = $self->{XS}->{$module};
        my $last_prefix = "";
        for my $func (@$functions) {
            my $class = $func->{class};
            my $prefix = $func->{prefix};
            $last_prefix = $prefix if $prefix;

            my $name = $func->{perl_name} || $func->{name};
            $name =~ s/^DEFINE_//;

            if ($name =~ /^mpxs_/) {
                #e.g. mpxs_Apache2__RequestRec_
                my $class_prefix = class_c_prefix($class);
                if ($name =~ /$class_prefix/) {
                    $prefix = class_mpxs_prefix($class);
                }
            }
            elsif ($name =~ /^ap_sub_req/) {
                $prefix = 'ap_sub_req_';
            }

            $name =~ s/^$prefix// if $prefix;

            push @{ $map{$name} }, [$module, $class];
        }

        # pure XS wrappers don't have the information about the
        # arguments they receive, since they manipulate the arguments
        # stack directly. therefore for these methods we can't tell
        # what are the objects they are invoked on
        for my $xs (@{ $self->{newXS}->{$module} || []}) {
            push @{ $map{$1} }, [$module, undef] if $xs->[0] =~ /.+::(.+)/;
        }
    }

    local $Data::Dumper::Terse    = 1;
    local $Data::Dumper::Sortkeys = 1;
    $Data::Dumper::Terse    = $Data::Dumper::Terse;    # warn
    $Data::Dumper::Sortkeys = $Data::Dumper::Sortkeys; # warn
    my $methods = Dumper(\%map);
    $methods =~ s/\n$//;

    my $package = "ModPerl::MethodLookup";
    my $file = catfile "lib", "ModPerl", "MethodLookup.pm";
    debug "creating $file";
    open my $fh, ">$file" or die "Can't open $file: $!";

    my $noedit_warning = $self->ModPerl::Code::noedit_warning_hash();

    print $fh <<EOF;
$noedit_warning
package $package;

use strict;
use warnings;

my \$methods = $methods;

EOF

    print $fh <<'EOF';

use base qw(Exporter);
use mod_perl2;

our @EXPORT = qw(print_method print_module print_object);
our $VERSION = $mod_perl2::VERSION;
use constant MODULE => 0;
use constant OBJECT  => 1;

my $modules;
my $objects;

sub _get_modules {
    for my $method (sort keys %$methods) {
        for my $item ( @{ $methods->{$method} }) {
            push @{ $modules->{$item->[MODULE]} }, [$method, $item->[OBJECT]];
        }
    }
}

sub _get_objects {
    for my $method (sort keys %$methods) {
        for my $item ( @{ $methods->{$method} }) {
            next unless defined $item->[OBJECT];
            push @{ $objects->{$item->[OBJECT]} }, [$method, $item->[MODULE]];
        }
    }
}

# if there is only one replacement method in 2.0 API we can
# automatically lookup it, up however if there are more than one
# (e.g. new()), we need to use a fully qualified value here
# of course the same if the package is not a mod_perl one.
#
# the first field represents the replacement method or undef if none
# exists, the second field is for extra comments (e.g. when there is
# no replacement method)
my $methods_compat = {
    # Apache2::
    gensym            => ['Symbol::gensym',
                          'or use "open my $fh, $file"'],
    module            => ['Apache2::Module::loaded',
                          ''],
    define            => ['exists_config_define',
                          ''],
    httpd_conf        => ['add_config',
                          ''],
    SERVER_VERSION    => ['get_server_version',
                          ''],
    can_stack_handlers=> [undef,
                          'there is no more need for that method in mp2'],

    # Apache2::RequestRec
    soft_timeout      => [undef,
                          'there is no more need for that method in mp2'],
    hard_timeout      => [undef,
                          'there is no more need for that method in mp2'],
    kill_timeout      => [undef,
                          'there is no more need for that method in mp2'],
    reset_timeout     => [undef,
                          'there is no more need for that method in mp2'],
    cleanup_for_exec  => [undef,
                          'there is no more need for that method in mp2'],
    send_http_header  => ['content_type',
                          ''],
    header_in         => ['headers_in',
                          'this method works in mod_perl 1.0 too'],
    header_out        => ['headers_out',
                          'this method works in mod_perl 1.0 too'],
    err_header_out    => ['err_headers_out',
                          'this method works in mod_perl 1.0 too'],
    register_cleanup  => ['cleanup_register',
                          ''],
    post_connection   => ['cleanup_register',
                          ''],
    content           => [undef, # XXX: Apache2::Request::what?
                          'use CGI.pm or Apache2::Request instead'],
    clear_rgy_endav   => ['special_list_clear',
                          ''],
    stash_rgy_endav   => [undef,
                          ''],
    run_rgy_endav     => ['special_list_call',
                          'this method is no longer needed'],
    seqno             => [undef,
                          'internal to mod_perl 1.0'],
    chdir_file        => [undef, # XXX: to be resolved
                          'temporary unavailable till the issue with chdir' .
                          ' in the threaded env is resolved'],
    log_reason        => ['log_error',
                          'not in the Apache 2.0 API'],
    READLINE          => [undef, # XXX: to be resolved
                          ''],
    send_fd_length    => [undef,
                          'not in the Apache 2.0 API'],
    send_fd           => ['sendfile',
                          'requires an offset argument'],
    is_main           => ['main',
                          'not in the Apache 2.0 API'],
    cgi_var           => ['subprocess_env',
                          'subprocess_env can be used with mod_perl 1.0'],
    cgi_env           => ['subprocess_env',
                          'subprocess_env can be used with mod_perl 1.0'],
    each_byterange    => [undef,
                          'now handled internally by ap_byterange_filter'],
    set_byterange     => [undef,
                          'now handled internally by ap_byterange_filter'],

    # Apache::File
    open              => [undef,
                          ''],
    close             => [undef, # XXX: also defined in APR::Socket
                          ''],
    tmpfile           => [undef,
                          'not in the Apache 2.0 API, ' .
                          'use File::Temp instead'],

    # Apache::Util
    size_string       => ['format_size',
                          ''],
    escape_uri        => ['unescape_path',
                          ''],
    escape_url        => ['escape_path',
                          'and requires a pool object'],
    unescape_uri      => ['unescape_url',
                          ''],
    unescape_url_info => [undef,
                          'use CGI::Util::unescape() instead'],
    escape_html       => [undef, # XXX: will be ap_escape_html
                          'ap_escape_html now requires a pool object'],
    parsedate         => ['parse_http',
                          ''],
    validate_password => ['password_validate',
                          ''],

    # Apache::Table
    #new               => ['make',
    #                      ''], # XXX: there are other 'new' methods

    # Apache::Connection
    auth_type         => ['ap_auth_type',
                          'now resides in the request object'],
};

sub avail_methods_compat {
    return keys %$methods_compat;
}

sub avail_methods {
    return keys %$methods;
}

sub avail_modules {
    my %modules = ();
    for my $method (keys %$methods) {
        for my $item ( @{ $methods->{$method} }) {
            $modules{$item->[MODULE]}++;
        }
    }
    return keys %modules;
}

sub preload_all_modules {
    _get_modules() unless $modules;
    eval "require $_" for sort keys %$modules;
}

sub _print_func {
    my $func = shift;
    my @args = @_ ? @_ : @ARGV;
    no strict 'refs';
    print( ($func->($_))[0]) for @args;
}

sub print_module { _print_func('lookup_module', @_) }
sub print_object { _print_func('lookup_object', @_) }

sub print_method {
    my @args = @_ ? @_ : @ARGV;
    while (@args) {
         my $method = shift @args;
         my $object = (@args &&
             (ref($args[0]) || $args[0] =~ /^(Apache2|ModPerl|APR)/))
             ? shift @args
             : undef;
         print( (lookup_method($method, $object))[0]);
    }
}

sub sep { return '-' x (shift() + 20) . "\n" }

# what modules contain the passed method.
# an optional object or a reference to it can be passed to help
# resolve situations where there is more than one module containing
# the same method. Inheritance is supported.
sub lookup_method {
    my ($method, $object) = @_;

    unless (defined $method) {
        my $hint = "No 'method' argument was passed\n";
        return ($hint);
    }

    # strip the package name for the fully qualified method
    $method =~ s/.+:://;

    if (exists $methods_compat->{$method}) {
        my ($replacement, $comment) = @{$methods_compat->{$method}};
        my $hint = "'$method' is not a part of the mod_perl 2.0 API\n";
        $comment = length $comment ? " $comment\n" : "";

        # some removed methods have no replacement
        return $hint . "$comment" unless defined $replacement;

        $hint .= "use '$replacement' instead. $comment";

        # if fully qualified don't look up its container
        return $hint if $replacement =~ /::/;

        my ($modules_hint, @modules) = lookup_method($replacement, $object);
        return $hint . $modules_hint;
    }
    elsif (!exists $methods->{$method}) {
        my $hint = "Don't know anything about method '$method'\n";
        return ($hint);
    }

    my @items = @{ $methods->{$method} };
    if (@items == 1) {
        my $module = $items[0]->[MODULE];
        my $hint = "To use method '$method' add:\n" . "\tuse $module ();\n";
        # we should really check that the method matches the object if
        # any was passed, but it may not always work
        return ($hint, $module);
    }
    else {
        if (defined $object) {
            my $class = ref $object || $object;
            for my $item (@items) {
                # real class or inheritance
                if ($class eq $item->[OBJECT] or
                    (ref($object) && $object->isa($item->[OBJECT]))) {
                    my $module = $item->[MODULE];
                    my $hint = "To use method '$method' add:\n" .
                        "\tuse $module ();\n";
                    return ($hint, $module);
                }
            }
            # fall-through
            local $" = ", ";
            my @modules = map $_->[MODULE], @items;
            my $hint = "Several modules (@modules) contain method '$method' " .
                "but none of them matches class '$class';\n";
            return ($hint);

        }
        else {
            my %modules = map { $_->[MODULE] => 1 } @items;
            # remove dups if any (e.g. $s->add_input_filter and
            # $r->add_input_filter are loaded by the same Apache2::Filter)
            my @modules = sort keys %modules;
            my $hint;
            if (@modules == 1) {
                $hint = "To use method '$method' add:\n\tuse $modules[0] ();\n";
                return ($hint, $modules[0]);
            }
            else {
                $hint = "There is more than one class with method '$method'\n" .
                    "try one of:\n" . join '', map {"\tuse $_ ();\n"} @modules;
                return ($hint, @modules);
            }
        }
    }
}

# what methods are contained in the passed module name
sub lookup_module {
    my ($module) = shift;

    unless (defined $module) {
        my $hint = "no 'module' argument was passed\n";
        return ($hint);
    }

    _get_modules() unless $modules;

    unless (exists $modules->{$module}) {
        my $hint = "don't know anything about module '$module'\n";
        return ($hint);
    }

    my @methods;
    my $max_len = 6;
    for ( @{ $modules->{$module} } ) {
        $max_len = length $_->[0] if length $_->[0] > $max_len;
        push @methods, $_->[0];
    }

    my $format = "%-${max_len}s %s\n";
    my $banner = sprintf($format, "Method", "Invoked on object type");
    my $hint = join '',
        ("\nModule '$module' contains the following XS methods:\n\n",
         $banner,  sep(length($banner)),
         map( { sprintf $format, $_->[0], $_->[1]||'???'}
             @{ $modules->{$module} }),
         sep(length($banner)));

    return ($hint, @methods);
}

# what methods can be invoked on the passed object (or its reference)
sub lookup_object {
    my ($object) = shift;

    unless (defined $object) {
        my $hint = "no 'object' argument was passed\n";
        return ($hint);
    }

    _get_objects() unless $objects;

    # a real object was passed?
    $object = ref $object || $object;

    unless (exists $objects->{$object}) {
        my $hint = "don't know anything about objects of type '$object'\n";
        return ($hint);
    }

    my @methods;
    my $max_len = 6;
    for ( @{ $objects->{$object} } ) {
        $max_len = length $_->[0] if length $_->[0] > $max_len;
        push @methods, $_->[0];
    }

    my $format = "%-${max_len}s %s\n";
    my $banner = sprintf($format, "Method", "Module");
    my $hint = join '',
        ("\nObjects of type '$object' can invoke the following XS methods:\n\n",
         $banner, sep(length($banner)),
         map({ sprintf $format, $_->[0], $_->[1]} @{ $objects->{$object} }),
         sep(length($banner)));

    return ($hint, @methods);

}

1;
EOF
    close $fh;
}

sub write_module_versions_file {
    my $self = shift;

    my $file = catfile "lib", "ModPerl", "DummyVersions.pm";
    debug "creating $file";
    open my $fh, ">$file" or die "Can't open $file: $!";

    my $noedit_warning = $self->ModPerl::Code::noedit_warning_hash();
    print $fh "$noedit_warning\n";

    my @modules = keys %{ $self->{XS} };
    push @modules, qw(ModPerl::MethodLookup);

    my $len = 0;
    for (@modules) {
        $len = length $_ if length $_ > $len;
    }

    require mod_perl2;
    $len += length '$::VERSION';
    for (sort @modules) {
        my $ver = module_version($_);
        printf $fh "package %s;\n%-${len}s = %s;\n\n",
            $_, '$'.$_."::VERSION", $ver;
    }
}

sub generate {
    my $self = shift;

    $self->prepare;

    for (qw(ModPerl::WrapXS Apache2 APR ModPerl)) {
        $self->write_makefilepl($_);
    }

    $self->write_typemap;

    for (qw(typedefs sv_convert)) {
        $self->write_typemap_h_file($_);
    }

    $self->get_functions;
    $self->get_structures;
    $self->write_export_file('exp') if Apache2::Build::AIX;
    $self->write_export_file('def') if Apache2::Build::WIN32;

    foreach my $module (sort keys %{ $self->{XS} }) {
        my $functions = $self->{XS}->{$module};
#        my ($root, $sub) = split '::', $module;
#        if (-e "$self->{XS_DIR}/$root/$sub/$sub.xs") {
#            $module = join '::', $root, "Wrap$sub";
#        }
        $self->write_makefilepl($module);
        $self->write_xs($module, $functions);
        $self->write_pm($module);
    }

    $self->write_lookup_method_file;
    $self->write_module_versions_file;
}

#three .sym files are generated:
#global   - global symbols
#ithreads - #ifdef USE_ITHREADS functions
#inline   - __inline__ functions
#the inline symbols are needed #ifdef MP_DEBUG
#since __inline__ will be turned off

my %multi_export = map { $_, 1 } qw(exp);

sub open_export_files {
    my ($self, $name, $ext) = @_;

    my $dir = $self->{XS_DIR};
    my %handles;
    my @types = qw(global inline ithreads);

    if ($multi_export{$ext}) {
        #write to multiple files
        for my $type (@types) {
            my $file = "$dir/${name}_$type.$ext";

            open my $fh, '>', $file or
              die "open $file: $!";

            $handles{$type} = $fh;
        }
    }
    else {
        #write to one file
        my $file = "$dir/$name.$ext";

        open my $fh, '>', $file or
          die "open $file: $!";

        for my $type (@types) {
            $handles{$type} = $fh;
        }
    }

    \%handles;
}

sub func_is_static {
    my ($self, $entry) = @_;
    if (my $attr = $entry->{attr}) {
        return 1 if grep { $_ eq 'static' } @$attr;
    }

    #C::Scan doesnt always pickup static __inline__
    return 1 if $entry->{name} =~ /^mpxs_/o;

    return 0;
}

sub func_is_inline {
    my ($self, $entry) = @_;
    if (my $attr = $entry->{attr}) {
        return 1 if grep { $_ eq '__inline__' } @$attr;
    }
    return 0;
}

sub export_file_header_exp {
    my $self = shift;
    "#!\n";
}

sub export_file_format_exp {
    my ($self, $val) = @_;
    "$val\n";
}

sub export_file_header_def {
    my $self = shift;
    "LIBRARY\n\nEXPORTS\n\n";
}

sub export_file_format_def {
    my ($self, $val) = @_;
    "   $val\n";
}

my $ithreads_exports = join '|', qw{
modperl_cmd_interp_
modperl_interp_
modperl_list_
modperl_tipool_
modperl_svptr_table_clone$
modperl_mgv_require_module$
};

sub export_func_handle {
    my ($self, $entry, $handles) = @_;

    if ($self->func_is_inline($entry)) {
        return $handles->{inline};
    }
    elsif ($entry->{name} =~ /^($ithreads_exports)/) {
        return $handles->{ithreads};
    }

    $handles->{global};
}

sub write_export_file {
    my ($self, $ext) = @_;

    my %files = (
        modperl => $ModPerl::FunctionTable,
        apache2 => $Apache2::FunctionTable,
        apr     => $APR::FunctionTable,
    );

    my $header = \&{"export_file_header_$ext"};
    my $format = \&{"export_file_format_$ext"};

    foreach my $key (sort keys %files) {
        my $table = $files{$key};
        my $handles = $self->open_export_files($key, $ext);

        my %seen; #only write header once if this is a single file
        for my $fh (values %$handles) {
            next if $seen{$fh}++;
            print $fh $self->$header();
        }

        # add the symbols which aren't the function table
        if ($key eq 'modperl') {
            my $fh = $handles->{global};
            for my $name (@global_structs) {
                print $fh $self->$format($name);
            }
        }

        for my $entry (@$table) {
            next if $self->func_is_static($entry);
            my $name = $entry->{name};

            my $fh = $self->export_func_handle($entry, $handles);

            print $fh $self->$format($name);
        }

        %seen = (); #only close handle once if this is a single file
        for my $fh (values %$handles) {
            next if $seen{$fh}++;
            close $fh;
        }
    }
}

sub stats {
    my $self = shift;

    $self->get_functions;
    $self->get_structures;

    my %stats;

    while (my ($module, $functions) = each %{ $self->{XS} }) {
        $stats{$module} += @$functions;
        if (my $newxs = $self->{newXS}->{$module}) {
            $stats{$module} += @$newxs;
        }
    }

    return \%stats;
}

sub generate_exports {
    my ($self, $fh) = @_;

    if (!$build->should_build_apache) {
        print $fh <<"EOF";
/* This is intentionnaly left blank, only usefull for static build */
const void *modperl_ugly_hack = NULL;
EOF
        return;
    }

    print $fh <<"EOF";
/*
 * This is indeed a ugly hack!
 * See also src/modules/perl/mod_perl.c for modperl_ugly_hack
 * If we don't build such a list of exported API functions, the over-zealous
 * linker can and will remove the unused functions completely. In order to
 * avoid this, we create this object and modperl_ugly_hack to create a
 * dependency between all the exported API and mod_perl.c
 */
const void *modperl_ugly_hack = NULL;
EOF

    for my $entry (@$ModPerl::FunctionTable) {
        next if $self->func_is_static($entry);
        unless (Apache2::Build::PERL_HAS_ITHREADS) {
            next if $entry->{name} =~ /^($ithreads_exports)/;
        }
        ( my $name ) = $entry->{name} =~ /^modperl_(.*)/;
        print $fh <<"EOF";
#ifndef modperl_$name
const void *modperl_hack_$name = (const void *)modperl_$name;
#endif

EOF
    }
}

1;
__END__
