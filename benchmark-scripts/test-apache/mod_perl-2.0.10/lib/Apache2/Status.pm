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
package Apache2::Status;

use strict;
use warnings FATAL => 'all';

use mod_perl2;

use Apache2::RequestIO ();
use Apache2::RequestRec ();
use Apache2::RequestUtil ();
use Apache2::ServerUtil ();

use File::Spec ();

use Apache2::Const -compile => qw(OK);

$Apache2::Status::VERSION = '4.01'; # mod_perl 2.0

use constant IS_WIN32 => ($^O eq "MSWin32");

my %status = (
    script    => "PerlRequire'd Files",
    inc       => "Loaded Modules",
    rgysubs   => "Compiled Registry Scripts",
    symdump   => "Symbol Table Dump",
    inh_tree  => "Inheritance Tree",
    isa_tree  => "ISA Tree",
    env       => "Environment",
    sig       => "Signal Handlers",
    myconfig  => "Perl Configuration",
);
delete $status{'sig'} if IS_WIN32;

if ($Apache2::PerlSections::Save) {
    $status{"section_config"} = "Perl Section Configuration";
}

my %requires = (
    deparse     => ["StatusDeparse",     "B::Deparse",     0.59, ],
    fathom      => ["StatusFathom",      "B::Fathom",      0.05, ],
    symdump     => ["",                  "Devel::Symdump", 2.00, ],
    dumper      => ["StatusDumper",      "Data::Dumper",   0,    ],
    b           => ["",                  "B",              0,    ],
    graph       => ["StatusGraph",       "B::Graph",       0.03, ],
    lexinfo     => ["StatusLexInfo",     "B::LexInfo",     0,    ],
    xref        => ["StatusXref",        "B::Xref",        1.01, ],
    terse       => ["StatusTerse",       "B::Terse",       0,    ],
    tersesize   => ["StatusTerseSize",   "B::TerseSize",   0.09, ],
    packagesize => ["StatusPackageSize", "B::TerseSize",   0.09, ],
    peek        => ["StatusPeek",        "Apache::Peek",   1.03, ],
);

sub has {
    my ($r, $what) = @_;

    return 0 unless exists $requires{$what};

    my ($opt, $module, $version) = @{ $requires{$what} };

    (my $file = $module) =~ s|::|/|;
    $file .= ".pm";

    # if !$opt we skip the testing for the option
    return 0 if $opt && !status_config($r, $opt);
    return 0 unless eval { require $file };
    my $mod_ver = $module->VERSION;
    $mod_ver =~ s/_.*//; # handle dev versions like 2.121_02
    return 0 unless $mod_ver && $mod_ver >= $version;

    return 1;
}

use constant CPAN_SEARCH => 'http://search.cpan.org/search?mode=module;query';

sub install_hint {
    my ($module) = @_;
    return qq{<p>Please install the } .
           qq{<a href="@{[CPAN_SEARCH]}=$module">$module</a> module.</p>};
}

sub status_config {
    my ($r, $key) = @_;
    return (lc($r->dir_config($key) || '') eq "on") ||
        (lc($r->dir_config('StatusOptionsAll') || '') eq "on");
}

sub menu_item {
    my ($self, $key, $val, $sub) = @_;
    $status{$key} = $val;
    no strict;
    no warnings 'redefine';
    *{"status_${key}"} = $sub if $sub and ref $sub eq 'CODE';
}

sub handler {
    my ($r) = @_;
    my $qs = $r->args || "";
    my $sub = "status_$qs";
    no strict 'refs';

    if ($qs =~ s/^(noh_\w+).*/$1/) {
        &{$qs}($r);
        return Apache2::Const::OK;
    }

    header($r);
    if (defined &$sub) {
        $r->print(@{ &{$sub}($r) });
    }
    elsif ($qs and %{$qs."::"}) {
        $r->print(symdump($r, $qs));
    }
    else {
        my $uri = $r->location;
        $r->print('<p>');
        $r->print(
            map { qq[<a href="$uri?$_">$status{$_}</a><br />\n] } sort { lc $a cmp lc $b } keys %status
        );
        $r->print('</p>');
    }
    $r->print("</body></html>");

    Apache2::Const::OK;
}

sub header {
    my $r = shift;
    my $start = scalar localtime $^T;
    my $srv = Apache2::ServerUtil::get_server_version();
    $r->content_type("text/html");
    my $v = $^V ? sprintf "v%vd", $^V : $];
    $r->print(<<"EOF");
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"
"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">

<html lang="en" xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Apache2::Status $Apache2::Status::VERSION</title>
    <style type="text/css">
      body {
        color: #000;
        background-color: #fff;
      }
      p.hdr {
        background-color: #ddd;
        border: 2px outset;
        padding: 3px;
        width: 99%;
     }
   </style>
  </head>
  <body>
    <p class="hdr">
      Embedded Perl version <b>$v</b> for <b>$srv</b> process <b>$$</b>,<br />
      running since $start
    </p>
EOF

}

sub symdump {
    my ($r, $package) = @_;

    return install_hint("Devel::Symdump") unless has($r, "symdump");

    # lc generates a (FATAL) warning if $r->dir_config is undef
    my $meth = lc($r->dir_config("StatusRdump") || '') eq "on"
        ? "rnew" : "new";
    my $sob = Devel::Symdump->$meth($package);
    return $sob->Apache2::Status::as_HTML($package, $r);
}

sub status_symdump {
    my ($r) = @_;
    [symdump($r, 'main')];
}

sub status_section_config {
    my ($r) = @_;
    require Apache2::PerlSections;
    ["<pre>", Apache2::PerlSections->dump, "</pre>"];
}

sub status_inc {
    my ($r) = @_;

    my $uri = $r->location;
    my @retval = (
        '<table border="1">',
        "<tr>",
        (map "<td><b>$_</b></td>", qw(Package Version Modified File)),
        "</tr>\n"
    );

    foreach my $file (sort keys %INC) {
        local $^W = 0;
        next if $file =~ m:^/:;
        next unless $file =~ m:\.pm:;
        next unless $INC{$file}; #e.g. fake Apache2/TieHandle.pm

        no strict 'refs';
        (my $module = $file) =~ s,/,::,g;
        $module =~ s,\.pm$,,;
        next if $module eq 'mod_perl';
        my $v = ${"$module\:\:VERSION"} || '0.00';
        my $mtime = -e $INC{$file} ? scalar localtime((stat $INC{$file})[9]) :
            'N/A';

        push @retval, (
            "<tr>",
            (map "<td>$_</td>",
                qq(<a href="$uri?$module">$module</a>),
                $v, $mtime, $INC{$file}),
            "</tr>\n"
        );
    }
    push @retval, "</table>\n";
    push @retval, "<p><b>\@INC</b> = <br />", join "<br />\n", @INC, "";
    \@retval;
}

sub status_script {
    my ($r) = @_;

    my @retval = (
        '<table border="1">',
        "<tr><td><b>PerlRequire</b></td><td><b>Location</b></td></tr>\n",
    );

    foreach my $file (sort keys %INC) {
        next if $file =~ m:\.(pm|al|ix)$:;
        push @retval,
            qq(<tr><td>$file</td><td>$INC{$file}</td></tr>\n);
    }
    push @retval, "</table>";
    \@retval;
}

my $RegistryCache;

sub registry_cache {
    my ($self, $cache) = @_;

    # XXX: generalize

    $RegistryCache = $cache if $cache;
    $RegistryCache || $Apache2::Registry;
}

sub get_packages_per_handler {
    my ($root, $stash) = @_;

    my %handlers = ();
    my @packages = get_packages($stash);
    for (@packages) {
        /^\*${root}::([\w:]+)::(\w+)::$/ && push @{ $handlers{$1} }, $2;
    }

    return %handlers;
}

sub get_packages {
    my ($stash) = @_;

    no strict 'refs';
    my @packages = ();
    for (keys %$stash) {
        return $stash unless $stash->{$_} =~ /::$/;
        push @packages, get_packages($stash->{$_});
    }
    return @packages;
}

sub status_rgysubs {
    my ($r) = @_;

    local $_;
    my $uri = $r->location;
    my $cache = __PACKAGE__->registry_cache;

    my @retval = "<h2>Compiled registry scripts grouped by their handler</h2>";

    push @retval,
      "<p><b>Click on package name to see its symbol table</b></p>\n";

    my $root = "ModPerl::ROOT";
    no strict 'refs';
    my %handlers = get_packages_per_handler($root, *{$root . "::"});
    for my $handler (sort keys %handlers) {
        push @retval, "<h4>$handler:</h4>\n<p>\n";
        for (sort @{ $handlers{$handler} }) {
            my $full = join '::', $root, $handler, $_;
            push @retval, qq(<a href="$uri?$full">$_</a>\n), "<br />";
        }
        push @retval, "</p>\n";
    }

    \@retval;
}

sub status_env {
    my ($r) = shift;

    my @retval = ("<p>\n");

    if ($r->handler eq 'modperl') {
        # the handler can be executed under the "modperl" handler
        push @retval,
            qq{<b>Under the "modperl" handler, the environment is</b>:};
        # XXX: I guess we could call $r->subprocess_env; and show how
        # would it look like under the 'perl-script' environment, but
        # under the 'modperl' handler %ENV doesn't get reset,
        # therefore on the first reload it'll see the bloated %ENV in
        # first place.
    } else {
        # the handler can be executed under the "perl-script" handler
        push @retval,
            qq{<b>Under the "perl-script" handler, the environment is</b>:};
    }
    push @retval, "\n</p>\n";
    push @retval, "<pre>",
        (map "$_ = " . escape_html($ENV{$_}||'') . "\n",
            sort keys %ENV), "</pre>";

    \@retval;
}

sub status_sig {
    ["<pre>",
     (map {
         my $val = $SIG{$_} || "";
         if ($val and ref $val eq "CODE") {
             # XXX: 2.0 doesn't have Apache2::Symbol
             if (my $cv = Apache2::Symbol->can('sv_name')) {
                 $val = "\\&".  $cv->($val);
             }
         }
         "$_ = $val\n" }
      sort keys %SIG),
     "</pre>"];
}

sub status_myconfig {
    ["<pre>", myconfig(), "</pre>"];
}

sub status_inh_tree {
    return has(shift, "symdump")
        ? ["<pre>", Devel::Symdump->inh_tree, "</pre>"]
        : install_hint("Devel::Symdump");
}

sub status_isa_tree {
    return has(shift, "symdump")
        ? ["<pre>", Devel::Symdump->isa_tree, "</pre>"]
        : install_hint("Devel::Symdump");
}

sub status_data_dump {
    my ($r) = @_;

    return install_hint('Data::Dumper') unless has($r, "dumper");

    my ($name, $type) = (split "/", $r->uri)[-2,-1];

    no strict 'refs';
    my @retval = "<p>\nData Dump of $name $type\n</p>\n<pre>\n";
    my $str = Data::Dumper->Dump([*$name{$type}], ['*'.$name]);
    $str = escape_html($str);
    $str =~ s/= \\/= /; #whack backwack
    push @retval, $str, "\n";
    push @retval, peek_link($r, $name, $type);
    push @retval, b_graph_link($r, $name);
    push @retval, "</pre>";
    \@retval;
}

sub cv_file {
    my $obj = shift;
    $obj->can('FILEGV') ? $obj->FILEGV->SV->PV : $obj->FILE;
}

sub status_cv_dump {
    my ($r) = @_;
    return [] unless has($r, "b");

    no strict 'refs';
    my ($name, $type) = (split "/", $r->uri)[-2,-1];
    # could be another child, which doesn't have this symbol table?
    return unless *$name{CODE};

    my @retval = "<p>Subroutine info for <b>$name</b></p>\n<pre>\n";
    my $obj    = B::svref_2object(*$name{CODE});
    my $file   = cv_file($obj);
    my $stash  = $obj->GV->STASH->NAME;
    my $script = $r->location;

    push @retval, "File: ",
        (-e $file ? qq(<a href="file:$file">$file</a>) : $file), "\n";

    my $cv    = $obj->GV->CV;
    my $proto = $cv->PV if $cv->can('PV');

    push @retval, qq(Package: <a href="$script?$stash">$stash</a>\n);
    push @retval, "Line: ",      $obj->GV->LINE, "\n";
    push @retval, "Prototype: ", $proto || "none", "\n";
    push @retval, "XSUB: ",      $obj->XSUB ? "yes" : "no", "\n";
    push @retval, peek_link($r, $name, $type);
    push @retval, b_graph_link($r, $name);
    push @retval, xref_link($r, $name);
    push @retval, b_lexinfo_link($r, $name);
    push @retval, b_terse_link($r, $name);
    push @retval, b_terse_size_link($r, $name);
    push @retval, b_deparse_link($r, $name);
    push @retval, b_fathom_link($r, $name);
    push @retval, "</pre>";
    \@retval;
}

sub b_lexinfo_link {
    my ($r, $name) = @_;

    return unless has($r, "lexinfo");

    my $script = $r->location;
    return qq(\n<a href="$script/$name?noh_b_lexinfo">Lexical Info</a>\n);
}

sub noh_b_lexinfo {
    my $r = shift;

    $r->content_type("text/plain");
    return unless has($r, "lexinfo");

    no strict 'refs';
    my ($name) = (split "/", $r->uri)[-1];
    $r->print("Lexical Info for $name\n\n");
    my $lexi = B::LexInfo->new;
    my $info = $lexi->cvlexinfo($name);
    $r->print(${ $lexi->dumper($info) });
}

my %b_terse_exp = ('slow' => 'syntax', 'exec' => 'execution', basic => 'syntax');

sub b_terse_link {
    my ($r, $name) = @_;

    return unless has($r, "terse");

    my $script = $r->location;
    my @retval;
    for (qw(exec basic)) {
        my $exp = "$b_terse_exp{$_} order";
        push @retval,
            qq(\n<a href="$script/$_/$name?noh_b_terse">Syntax Tree Dump ($exp)</a>\n);
    }
    join '', @retval;
}

sub noh_b_terse {
    my $r = shift;

    $r->content_type("text/plain");
    return unless has($r, "terse");

    no strict 'refs';
    my ($arg, $name) = (split "/", $r->uri)[-2,-1];
    $r->print("Syntax Tree Dump ($b_terse_exp{$arg}) for $name\n\n");

    # XXX: blead perl dumps things to STDERR, though the same version
    # works fine with 1.27
    # B::Concise couldn't parse XS code before perl patch 24681 (perl 5.9.3)
    # B::Terse is deprecated and just a wrapper around B::Concise now adays
    eval { B::Concise::compile("-terse", "-$arg", $name)->() };
    if ($@) {
        $r->print("B::Concise has failed: $@");
    }
}

sub b_terse_size_link {
    my ($r, $name) = @_;

    return unless has($r, "tersesize");

    my $script = $r->location;
    my @retval;
    for (qw(exec slow)) {
        my $exp = "$b_terse_exp{$_} order";
        push @retval,
            qq(\n<a href="$script/$_/$name?noh_b_terse_size">Syntax Tree Size ($exp)</a>\n);
    }
    join '', @retval;
}

sub noh_b_terse_size {
    my $r = shift;

    $r->content_type("text/html");
    return unless has($r, "tersesize");

    $r->print('<pre>');
    my ($arg, $name) = (split "/", $r->uri)[-2,-1];
    my $uri = $r->location;
    my $link = qq{<a href="$uri/$name/CODE?cv_dump">$name</a>};
    $r->print("Syntax Tree Size ($b_terse_exp{$arg} order) for $link\n\n");
    B::TerseSize::compile($arg, $name)->();
}

sub b_package_size_link {
    my ($r, $name) = @_;

    return unless has($r, "packagesize");

    my $script = $r->location;
    qq(<a href="$script/$name?noh_b_package_size">Memory Usage</a>\n);
}

sub noh_b_package_size {
    my ($r) = @_;

    $r->content_type("text/html");
    return unless has($r, "packagesize");

    $r->print('<pre>');

    no strict 'refs';
    my ($package) = (split "/", $r->uri)[-1];
    my $script = $r->location;
    $r->print("Memory Usage for package $package\n\n");
    my ($subs, $opcount, $opsize) = B::TerseSize::package_size($package);
    my $Kb = sprintf "%.2f", $opsize / 1024;
    my $Mb = sprintf "%.2f", $Kb / 1000;
    $r->print("Totals: $opsize bytes, $Kb Kb, $Mb Mb | $opcount OPs\n\n");

    my $nlen = 0;
    my @keys = map {
        $nlen = length > $nlen ? length : $nlen;
        $_;
    } (sort { $subs->{$b}->{size} <=> $subs->{$a}->{size} } keys %$subs);

    my $clen = $subs->{$keys[0]}->{count} ?
        length $subs->{$keys[0]}->{count} : 0;
    my $slen = length $subs->{$keys[0]}->{size};

    for my $name (@keys) {
        my $stats = $subs->{$name};
        if ($name =~ /^my /) {
            $r->printf("%-${nlen}s %${slen}d bytes\n", $name, $stats->{size});
        }
        elsif ($name =~ /^\*(\w+)\{(\w+)\}/) {
            my $link = qq(<a href="$script/$package\::$1/$2?data_dump">);
            $r->printf("$link%-${nlen}s</a> %${slen}d bytes\n",
                       $name, $stats->{size});
        }
        else {
            my $link =
                qq(<a href="$script/slow/$package\::$name?noh_b_terse_size">);
            $r->printf("$link%-${nlen}s</a> %${slen}d bytes | %${clen}d OPs\n",
                       $name, $stats->{size}, $stats->{count});
        }
    }
}

sub b_deparse_link {
    my ($r, $name) = @_;

    return unless has($r, "deparse");

    my $script = $r->location;
    return qq(\n<a href="$script/$name?noh_b_deparse">Deparse</a>\n);
}

sub noh_b_deparse {
    my $r = shift;

    $r->content_type("text/plain");
    return unless has($r, "deparse");

    my $name = (split "/", $r->uri)[-1];
    $r->print("Deparse of $name\n\n");
    my $deparse = B::Deparse->new(split /\s+/,
                                  $r->dir_config('StatusDeparseOptions')||"");
    my $body = $deparse->coderef2text(\&{$name});
    $r->print("sub $name $body");
}

sub b_fathom_link {
    my ($r, $name) = @_;

    return unless has($r, "fathom");

    my $script = $r->location;
    return qq(\n<a href="$script/$name?noh_b_fathom">Fathom Score</a>\n);
}

sub noh_b_fathom {
    my $r = shift;

    $r->content_type("text/plain");
    return unless has($r, "fathom");

    my $name = (split "/", $r->uri)[-1];
    $r->print("Fathom Score of $name\n\n");
    my $fathom = B::Fathom->new(split /\s+/,
                                $r->dir_config('StatusFathomOptions')||"");
    $r->print($fathom->fathom(\&{$name}));
}

sub peek_link {
    my ($r, $name, $type) = @_;

    return unless has($r, "peek");

    my $script = $r->location;
    return qq(\n<a href="$script/$name/$type?noh_peek">Peek Dump</a>\n);
}

sub noh_peek {
    my $r = shift;

    $r->content_type("text/plain");
    return unless has($r, "peek");

    no strict 'refs';
    my ($name, $type) = (split "/", $r->uri)[-2,-1];
    $type =~ s/^FUNCTION$/CODE/;
    $r->print("Peek Dump of $name $type\n\n");
    Apache::Peek::Dump(*{$name}{$type});
}

sub xref_link {
    my ($r, $name) = @_;

    return unless has($r, "xref");

    my $script = $r->location;
    return qq(\n<a href="$script/$name?noh_xref">Cross Reference Report</a>\n);
}

sub noh_xref {
    my $r = shift;

    $r->content_type("text/plain");
    return unless has($r, "xref");

    (my $thing = $r->path_info) =~ s:^/::;
    $r->print("Xref of $thing\n");
    B::Xref::compile($thing)->();
}

$Apache2::Status::BGraphCache ||= 0;
if ($Apache2::Status::BGraphCache) {
    Apache2->server->push_handlers(PerlChildExitHandler => sub {
        unlink keys %Apache2::Status::BGraphCache;
    });
}

sub b_graph_link {
    my ($r, $name) = @_;

    return unless has($r, "graph");

    my $script = $r->location;
    return qq(\n<a href="$script/$name?noh_b_graph">OP Tree Graph</a>\n);
}

sub noh_b_graph {
    my $r = shift;

    return unless has($r, "graph");

    untie *STDOUT;

    my $dir = File::Spec->catfile(Apache2::ServerUtil::server_root(),
        ($r->dir_config("GraphDir") || "logs/b_graphs"));

    mkdir $dir, 0755 unless -d $dir;

    (my $thing = $r->path_info) =~ s:^/::;
    $thing =~ s{::}{-}g; # :: is not allowed in the filename on some OS
    my $type = "dot";
    my $file = "$dir/$thing.$$.gif";

    unless (-e $file) {
        my $rv = tie *STDOUT, "B::Graph", $r, $file;
        unless ($rv) {
            $r->content_type("text/plain");
            $r->print("dot not found\n");
        }
        else {
            B::Graph::compile("-$type", $thing)->();
            (tied *STDOUT)->{graph}->close;
        }
    }

    if (-s $file) {
        $r->content_type("image/gif");
        $r->sendfile($file);
    }
    else {
        $r->content_type("text/plain");
        $r->print("Graph of $thing failed!\n");
    }
    if ($Apache2::Status::BGraphCache) {
        $Apache2::Status::BGraphCache{$file}++;
    }
    else {
        unlink $file;
    }

    0;
}

sub B::Graph::TIEHANDLE {
    my ($class, $r, $file) = @_;

    if ($file =~ /^([^<>|;]+)$/) {
        $file = $1;
    }
    else {
        die "TAINTED data in THING=> ($file)";
    }

    $ENV{PATH} = join ":", qw{/usr/bin /usr/local/bin};
    my $dot = $r->dir_config("Dot") || "dot";

    require IO::File;
    my $pipe = IO::File->new("|$dot -Tgif -o $file");
    $pipe && $pipe->autoflush(1);

    if ($pipe) {
        return bless {
            graph => $pipe,
            r     => $r,
        }, $class;
    }
    else {
        return;
    }
}

sub B::Graph::PRINT {
    my $self = shift;

    $self->{graph}->print(@_);
}

my %can_dump = map {$_,1} qw(scalars arrays hashes);

sub as_HTML {
    my ($self, $package, $r) = @_;

    my @m = qw(<table>);
    my $uri = $r->location;
    my $is_main = $package eq "main";

    my $do_dump = has($r, "dumper");

    my @methods = sort keys %{$self->{'AUTOLOAD'}};

    if ($is_main) {
        @methods = grep { $_ ne "packages" } @methods;
        unshift @methods, "packages";
    }

    for my $type (@methods) {
        (my $dtype = uc $type) =~ s/E?S$//;
        push @m, "<tr><td valign=\"top\"><b>$type</b></td>";
        my @line = ();

        for (sort $self->_partdump(uc $type)) {
            s/([\000-\037\177])/ '^' . pack('c', ord($1) ^ 64)/eg;

            if ($type eq "scalars") {
                no strict 'refs';
                next unless defined eval { $$_ };
            }

            if ($type eq "packages") {
                push @line, qq(<a href="$uri?$_">$_</a>);
            }
            elsif ($type eq "functions") {
                if (has($r, "b")) {
                    push @line, qq(<a href="$uri/$_/$dtype?cv_dump">$_</a>);
                }
                else {
                    push @line, $_;
                }
            }
            elsif ($do_dump and $can_dump{$type}) {
                next if /_</;
                push @line, qq(<a href="$uri/$_/$dtype?data_dump">$_</a>);
            }
            else {
                push @line, $_;
            }
        }
        push @m, "<td>" . join(", ", @line) . "</td></tr>\n";
    }
    push @m, "</table>";

    return join "\n", @m, "<hr>", b_package_size_link($r, $package);
}

sub escape_html {
    my $str = shift;

    $str =~ s/&/&amp;/g;
    $str =~ s/</&lt;/g;
    $str =~ s/>/&gt;/g;

    return $str;
}

sub myconfig {
    require Config;
    # Config::myconfig(); fails under threads with (5.8.0 < perl < 5.8.3)
    # "Modification of a read-only value attempted"
    # provide a workaround
    if ($Config::Config{useithreads} and $] > 5.008 and $] < 5.008003) {
        return $Config::summary_expanded if $Config::summary_expanded;
        ($Config::summary_expanded = $Config::summary) =~
            s{\$(\w+)}
             { my $c = $Config::Config{$1}; defined($c) ? $c : 'undef' }ge;
        return $Config::summary_expanded;
    }
    else {
        return Config::myconfig();
  }
}

# mp2 modules have to deal with situations where a binary incompatible
# mp1 version of the same module is installed in the same
# tree. therefore when checking for a certain version, one wants to
# check the version of the module 'require()' will find without
# loading that module. this function partially adopted from
# ExtUtils::MM_Unix does just that. it returns the version number of
# the first module that it finds, forcing numerical context, making
# the return value suitable for immediate numerical comparison
# operation. (i.e. 2.03-dev will be returned as 2.03,  0 will be
# returned when the parsing has failed or a module wasn't found).
sub parse_version {
    my $name = shift;
    die "no module name passed" unless $name;
    my $file = File::Spec->catfile(split /::/, $name) . '.pm';
    for my $dir (@INC) {
        next if ref $dir; # skip code refs

        my $pmfile = File::Spec->catfile($dir, $file);
        next unless -r $pmfile;

        open my $fh, $pmfile or die "can't open $pmfile: $!";

        my $inpod = 0;
        my $version;
        while (<$fh>) {
            $inpod = /^=(?!cut)/ ? 1 : /^=cut/ ? 0 : $inpod;
            next if $inpod || /^\s*#/;

            chomp;
            next unless /([\$*])(([\w\:\']*)\bVERSION)\b.*\=/;
            { local($1, $2); ($_ = $_) = /(.*)/; } # untaint
            my $eval = qq{
                package Apache2::Status::_version;
                no strict;

                local $1$2;
                \$$2=undef; do {
                    $_
                }; \$$2
            };
            no warnings;
            $version = eval $eval;
            warn "Could not eval '$eval' in $pmfile: $@" if $@;
            last;
        }

        close $fh;

        # avoid situations like "2.03-dev" and return a numerical
        # version
        if (defined $version) {
            no warnings;
            $version += 0; # force number
            return $version;
        }
    }

    return 0; # didn't find the file or the version number
}

1;

__END__

