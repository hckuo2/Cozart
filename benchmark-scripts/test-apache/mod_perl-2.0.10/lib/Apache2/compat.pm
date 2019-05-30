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
package Apache2::compat;

use strict;
use warnings FATAL => 'all';
no warnings 'redefine';

#1.xx compat layer
#some of this will stay as-is
#some will be implemented proper later on

#there's enough here to get simple registry scripts working
#add to startup.pl:
#use Apache2::compat ();
#use lib ...; #or something to find 1.xx Apache2::Registry

#Alias /perl /path/to/perl/scripts
#<Location /perl>
#   Options +ExecCGI
#   SetHandler modperl
#   PerlResponseHandler Apache2::Registry
#</Location>

use Apache2::Connection ();
use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::Access ();
use Apache2::Module ();
use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::RequestUtil ();
use Apache2::Response ();
use Apache2::SubRequest ();
use Apache2::Filter ();
use Apache2::Util ();
use Apache2::Log ();
use Apache2::URI ();
use APR::Date ();
use APR::Table ();
use APR::Pool ();
use APR::URI ();
use APR::Util ();
use APR::Brigade ();
use APR::Bucket ();
use mod_perl2 ();

use Symbol ();
use File::Spec ();

use APR::Const -compile => qw(FINFO_NORM);

BEGIN {
    $INC{'Apache.pm'} = __FILE__;

    $INC{'Apache/Constants.pm'} = __FILE__;

    $INC{'Apache/File.pm'} = __FILE__;

    $INC{'Apache/Table.pm'} = __FILE__;
}

($Apache::Server::Starting, $Apache::Server::ReStarting) =
    Apache2::ServerUtil::restart_count() == 1 ? (1, 0) : (0, 1);

# api => "overriding code"
# the overriding code, needs to "return" the original CODE reference
# when eval'ed , so that it can be restored later
my %overridable_mp2_api = (
    'Apache2::RequestRec::filename' => <<'EOI',
{
    require Apache2::RequestRec;
    require APR::Finfo;
    my $orig_sub = *Apache2::RequestRec::filename{CODE};
    *Apache2::RequestRec::filename = sub {
        my ($r, $newfile) = @_;
        my $old_filename;
        if (defined $newfile) {
            $old_filename = $r->$orig_sub($newfile);
            die "'$newfile' doesn't exist" unless -e $newfile;
            $r->finfo(APR::Finfo::stat($newfile, APR::Const::FINFO_NORM, $r->pool));
        }
        else {
            $old_filename = $r->$orig_sub();
        }
        return $old_filename;
    };
    $orig_sub;
}

EOI
    'Apache2::RequestRec::notes' => <<'EOI',
{
    require Apache2::RequestRec;
    my $orig_sub = *Apache2::RequestRec::notes{CODE};
    *Apache2::RequestRec::notes = sub {
        my $r = shift;
        return wantarray()
            ?       ($r->table_get_set(scalar($r->$orig_sub), @_))
            : scalar($r->table_get_set(scalar($r->$orig_sub), @_));
    };
    $orig_sub;
}
EOI

    'Apache2::RequestRec::finfo' => <<'EOI',
{
    require APR::Finfo;
    my $orig_sub = *APR::Finfo::finfo{CODE};
    sub Apache2::RequestRec::finfo {
        my $r = shift;
        stat $r->filename;
        \*_;
    }
    $orig_sub;
}
EOI

    'Apache2::Connection::local_addr' => <<'EOI',
{
    require Apache2::Connection;
    require Socket;
    require APR::SockAddr;
    my $orig_sub = *Apache2::Connection::local_addr{CODE};
    *Apache2::Connection::local_addr = sub {
        my $c = shift;
        Socket::pack_sockaddr_in($c->$orig_sub->port,
                                 Socket::inet_aton($c->$orig_sub->ip_get));
    };
    $orig_sub;
}
EOI

    'Apache2::Connection::remote_addr' => <<'EOI',
{
    require Apache2::Connection;
    require APR::SockAddr;
    require Socket;
    my $orig_sub;
    if (defined *Apache2::Connection::client_addr{CODE}) { # httpd-2.4
        $orig_sub = *Apache2::Connection::client_addr{CODE};
    } else { # httpd-2.2
        $orig_sub = *Apache2::Connection::remote_addr{CODE};
    }
    *Apache2::Connection::remote_addr = sub {
        my $c = shift;
        if (@_) {
            my $addr_in = shift;
            my ($port, $addr) = Socket::unpack_sockaddr_in($addr_in);
            $c->$orig_sub->ip_set($addr);
            $c->$orig_sub->port_set($port);
        }
        else {
            Socket::pack_sockaddr_in($c->$orig_sub->port,
                                     Socket::inet_aton($c->$orig_sub->ip_get));
        }
    };
    $orig_sub;
}
EOI

    'Apache2::Module::top_module' => <<'EOI',
{
    require Apache2::Module;
    my $orig_sub = *Apache2::Module::top_module{CODE};
    *Apache2::Module::top_module = sub {
        shift;
        $orig_sub->(@_);
    };
    $orig_sub;
}
EOI

    'Apache2::Module::get_config' => <<'EOI',
{
    require Apache2::Module;
    my $orig_sub = *Apache2::Module::get_config{CODE};
    *Apache2::Module::get_config = sub {
        shift;
        $orig_sub->(@_);
    };
    $orig_sub;
}
EOI

    'APR::URI::unparse' => <<'EOI',
{
    require APR::URI;
    my $orig_sub = *APR::URI::unparse{CODE};
    *APR::URI::unparse = sub {
        my ($uri, $flags) = @_;

        if (defined $uri->hostname && !defined $uri->scheme) {
            # we do this only for back compat, the new APR::URI is
            # protocol-agnostic and doesn't fallback to 'http' when the
            # scheme is not provided
            $uri->scheme('http');
        }

        $orig_sub->(@_);
    };
    $orig_sub;
}
EOI

    'Apache2::Util::ht_time' => <<'EOI',
{
    require Apache2::Util;
    my $orig_sub = *Apache2::Util::ht_time{CODE};
    *Apache2::Util::ht_time = sub {
        my $r = Apache2::compat::request('Apache2::Util::ht_time');
        return $orig_sub->($r->pool, @_);
    };
    $orig_sub;
}

EOI

);

my %overridden_mp2_api = ();

# this function enables back-compatible APIs which can't coexist with
# mod_perl 2.0 APIs with the same name and therefore it should be
# avoided if possible.
#
# it expects a list of fully qualified functions, like
# "Apache2::RequestRec::finfo"
sub override_mp2_api {
    my (@subs) = @_;

    for my $sub (@subs) {
        unless (exists $overridable_mp2_api{$sub}) {
            die __PACKAGE__ . ": $sub is not overridable";
        }
        if (exists $overridden_mp2_api{$sub}) {
            warn __PACKAGE__ . ": $sub has been already overridden";
            next;
        }
        $overridden_mp2_api{$sub} = eval $overridable_mp2_api{$sub};
        unless (exists $overridden_mp2_api{$sub} &&
                ref($overridden_mp2_api{$sub}) eq 'CODE') {
            die "overriding $sub didn't return a CODE ref";
        }
    }
}

# restore_mp2_api does the opposite of override_mp2_api(), it removes
# the overriden API and restores the original mod_perl 2.0 API
sub restore_mp2_api {
    my (@subs) = @_;

    for my $sub (@subs) {
        unless (exists $overridable_mp2_api{$sub}) {
            die __PACKAGE__ . ": $sub is not overridable";
        }
        unless (exists $overridden_mp2_api{$sub}) {
            warn __PACKAGE__ . ": can't restore $sub, " .
                "as it has not been overridden";
            next;
        }
        # XXX: 5.8.2+ can't delete and assign at once - gives:
        #    Attempt to free unreferenced scalar
        # after perl_clone. the 2 step works ok. to reproduce:
        # t/TEST -maxclients 1 perl/ithreads2.t compat/request.t
        my $original_sub = $overridden_mp2_api{$sub};
        delete $overridden_mp2_api{$sub};
        no warnings 'redefine';
        no strict 'refs';
        *$sub = $original_sub;
    }
}

sub request {
    my $what = shift;

    my $r = Apache2::RequestUtil->request;

    unless ($r) {
        die "cannot use $what ",
            "without 'SetHandler perl-script' ",
            "or 'PerlOptions +GlobalRequest'";
    }

    $r;
}

{
    my $orig_sub = *Apache2::Module::top_module{CODE};
    *Apache2::Module::top_module = sub {
        $orig_sub->();
    };
}

{
    my $orig_sub = *Apache2::Module::get_config{CODE};
    *Apache2::Module::get_config = sub {
        shift if $_[0] eq 'Apache2::Module';
        $orig_sub->(@_);
    };
}

package Apache::Server;
# XXX: is that good enough? see modperl/src/modules/perl/mod_perl.c:367
our $CWD = Apache2::ServerUtil::server_root();

our $AddPerlVersion = 1;

sub warn {
    shift if @_ and $_[0] eq 'Apache::Server';
    Apache2::ServerRec::warn(@_);
}

package Apache;

sub request {
    return Apache2::compat::request(@_);
}

sub unescape_url_info {
    my ($class, $string) = @_;
    Apache2::URI::unescape_url($string);
    $string =~ tr/+/ /;
    $string;
}

#sorry, have to use $r->Apache2::args at the moment
#for list context splitting

sub args {
    my $r = shift;
    my $args = $r->args;
    return $args unless wantarray;
    return $r->parse_args($args);
}

sub server_root_relative {
    my $class = shift;
    if (@_ && defined($_[0]) && File::Spec->file_name_is_absolute($_[0])) {
         return File::Spec->catfile(@_);
    }
    else {
        File::Spec->catfile(Apache2::ServerUtil::server_root(), @_);
    }
}

sub exit {
    require ModPerl::Util;

    my $status = 0;
    my $nargs = @_;

    if ($nargs == 2) {
        $status = $_[1];
    }
    elsif ($nargs == 1 and $_[0] =~ /^\d+$/) {
        $status = $_[0];
    }

    ModPerl::Util::exit($status);
}

#XXX: warn
sub import {
}

sub untaint {
    shift;
    require ModPerl::Util;
    ModPerl::Util::untaint(@_);
}

sub module {
    require Apache2::Module;
    die 'Usage: Apache2->module($name)' if @_ != 2;
    return Apache2::Module::loaded($_[1]);
}

sub gensym {
    return Symbol::gensym();
}

sub define {
    shift if @_ == 2;
    Apache2::ServerUtil::exists_config_define(@_);
}

sub log_error {
    Apache2::ServerUtil->server->log_error(@_);
}

sub warn {
    shift if @_ and $_[0] eq 'Apache';
    Apache2::ServerRec::warn(@_);
}

sub httpd_conf {
    shift;
    my $obj;
    eval { $obj = Apache2::RequestUtil->request };
    $obj = Apache2::ServerUtil->server if $@;
    my $err = $obj->add_config([split /\n/, join '', @_]);
    die $err if $err;
}

# mp2 always can stack handlers
sub can_stack_handlers { 1; }

sub push_handlers {
    shift;
    Apache2::ServerUtil->server->push_handlers(@_);
}

sub set_handlers {
    shift;
    Apache2::ServerUtil->server->set_handlers(@_);
}

sub get_handlers {
    shift;
    Apache2::ServerUtil->server->get_handlers(@_);
}

package Apache::Constants;

use Apache2::Const ();

sub import {
    my $class = shift;
    my $package = scalar caller;

    my @args = @_;

    # treat :response as :common - it's not perfect
    # but simple and close enough for the majority
    my %args = map { s/^:response$/:common/; $_ => 1 } @args;

    Apache2::Const->compile($package => keys %args);
}

#no need to support in 2.0
sub export {}

sub SERVER_VERSION { Apache2::ServerUtil::get_server_version() }

package Apache2::RequestRec;

use Apache2::Const -compile => qw(REMOTE_NAME);

#no longer exist in 2.0
sub soft_timeout {}
sub hard_timeout {}
sub kill_timeout {}
sub reset_timeout {}

# this function is from mp1's Apache2::SubProcess 3rd party module
# which is now a part of mp2 API. this function doesn't exist in 2.0.
sub cleanup_for_exec {}

sub current_callback {
    require ModPerl::Util;
    return ModPerl::Util::current_callback();
}

sub send_http_header {
    my ($r, $type) = @_;

    # since send_http_header() in mp1 was telling mod_perl not to
    # parse headers and in mp2 one must call $r->content_type($type) to
    # perform the same, we make sure that this happens
    $type = $r->content_type || 'text/html' unless defined $type;

    $r->content_type($type);
}

#we support Apache2::RequestUtil->request; this is needed to support $r->request
#XXX: seems sorta backwards
*request = \&Apache2::request;

sub table_get_set {
    my ($r, $table) = (shift, shift);
    my ($key, $value) = @_;

    if (1 == @_) {
        return wantarray()
            ?       ($table->get($key))
            : scalar($table->get($key));
    }
    elsif (2 == @_) {
        if (defined $value) {
            return wantarray()
                ?        ($table->set($key, $value))
                :  scalar($table->set($key, $value));
        }
        else {
            return wantarray()
                ?       ($table->unset($key))
                : scalar($table->unset($key));
        }
    }
    elsif (0 == @_) {
        return $table;
    }
    else {
        my $name = (caller(1))[3];
        $r->warn("Usage: \$r->$name([key [,val]])");
    }
}

sub header_out {
    my $r = shift;
    return wantarray()
        ?       ($r->table_get_set(scalar($r->headers_out), @_))
        : scalar($r->table_get_set(scalar($r->headers_out), @_));
}

sub header_in {
    my $r = shift;
    return wantarray()
        ?       ($r->table_get_set(scalar($r->headers_in), @_))
        : scalar($r->table_get_set(scalar($r->headers_in), @_));
}

sub err_header_out {
    my $r = shift;
    return wantarray()
        ?       ($r->table_get_set(scalar($r->err_headers_out), @_))
        : scalar($r->table_get_set(scalar($r->err_headers_out), @_));
}


sub register_cleanup {
    shift->pool->cleanup_register(@_);
}

*post_connection = \&register_cleanup;

sub get_remote_host {
    my ($r, $type) = @_;
    $type = Apache2::Const::REMOTE_NAME unless defined $type;
    $r->connection->get_remote_host($type, $r->per_dir_config);
}

sub parse_args {
    my ($r, $string) = @_;
    return () unless defined $string and $string;

    return map {
        tr/+/ /;
        s/%([0-9a-fA-F]{2})/pack("C",hex($1))/ge;
        $_;
    } split /[=&;]/, $string, -1;
}

use Apache2::Const -compile => qw(MODE_READBYTES);
use APR::Const    -compile => qw(SUCCESS BLOCK_READ);

use constant IOBUFSIZE => 8192;

sub content {
    my $r = shift;

    my $bb = APR::Brigade->new($r->pool,
                               $r->connection->bucket_alloc);

    my $data = '';
    my $seen_eos = 0;
    do {
        $r->input_filters->get_brigade($bb, Apache2::Const::MODE_READBYTES,
                                       APR::Const::BLOCK_READ, IOBUFSIZE);
        while (!$bb->is_empty) {
            my $b = $bb->first;

            if ($b->is_eos) {
                $seen_eos++;
                last;
            }

            if ($b->read(my $buf)) {
                $data .= $buf;
            }

            $b->delete;
        }
    } while (!$seen_eos);

    $bb->destroy;

    return $data unless wantarray;
    return $r->parse_args($data);
}

sub server_root_relative {
    my $r = shift;
    File::Spec->catfile(Apache2::ServerUtil::server_root(), @_);
}

sub clear_rgy_endav {
    my ($r, $script_name) = @_;
    require ModPerl::Global;
    my $package = 'Apache2::ROOT' . $script_name;
    ModPerl::Global::special_list_clear(END => $package);
}

sub stash_rgy_endav {
    #see run_rgy_endav
}

#if somebody really wants to have END subroutine support
#with the 1.x Apache2::Registry they will need to configure:
# PerlHandler Apache2::Registry Apache2::compat::run_rgy_endav
sub Apache2::compat::run_rgy_endav {
    my $r = shift;

    require ModPerl::Global;
    require Apache2::PerlRun; #1.x's
    my $package = Apache2::PerlRun->new($r)->namespace;

    ModPerl::Global::special_list_call(END => $package);
}

sub seqno {
    1;
}

sub chdir_file {
    #XXX resolve '.' in @INC to basename $r->filename
}

#XXX: would like to have a proper implementation
#that reads line-by-line as defined by $/
#the best way will probably be to use perlio in 5.8.0
#anything else would be more effort than it is worth
sub READLINE {
    my $r = shift;
    my $line;
    $r->read($line, $r->headers_in->get('Content-length'));
    $line ? $line : undef;
}

#XXX: howto convert PerlIO to apr_file_t
#so we can use the real ap_send_fd function
#2.0 ap_send_fd() also has an additional offset parameter

sub send_fd_length {
    my ($r, $fh, $length) = @_;

    my $buff;
    my $total_bytes_sent = 0;
    my $len;

    return 0 if $length == 0;

    if (($length > 0) && ($total_bytes_sent + IOBUFSIZE) > $length) {
        $len = $length - $total_bytes_sent;
    }
    else {
        $len = IOBUFSIZE;
    }

    binmode $fh;

    while (CORE::read($fh, $buff, $len)) {
        $total_bytes_sent += $r->puts($buff);
    }

    $total_bytes_sent;
}

sub send_fd {
    my ($r, $fh) = @_;
    $r->send_fd_length($fh, -1);
}

sub is_main { !shift->main }

# really old back-compat methods, they shouldn't be used in mp1
*cgi_var = *cgi_env = \&Apache2::RequestRec::subprocess_env;

package Apache::File;

use Fcntl ();
use Symbol ();
use Carp ();

sub new {
    my ($class) = shift;
    my $fh = Symbol::gensym;
    my $self = bless $fh, ref($class)||$class;
    if (@_) {
        return $self->open(@_) ? $self : undef;
    }
    else {
        return $self;
    }
}

sub open {
    my ($self) = shift;

    Carp::croak("no Apache2::File object passed")
          unless $self && ref($self);

    # cannot forward @_ to open() because of its prototype
    if (@_ > 1) {
        my ($mode, $file) = @_;
        CORE::open $self, $mode, $file;
    }
    else {
        my $file = shift;
        CORE::open $self, $file;
    }
}

sub close {
    my ($self) = shift;
    CORE::close $self;
}

my $TMPNAM = 'aaaaaa';
my $TMPDIR = $ENV{'TMPDIR'} || $ENV{'TEMP'} || '/tmp';
($TMPDIR) = $TMPDIR =~ /^([^<>|;*]+)$/; #untaint
my $Mode = Fcntl::O_RDWR()|Fcntl::O_EXCL()|Fcntl::O_CREAT();
my $Perms = 0600;

sub tmpfile {
    my $class = shift;
    my $limit = 100;
    my $r = Apache2::compat::request('Apache::File->tmpfile');

    while ($limit--) {
        my $tmpfile = "$TMPDIR/${$}" . $TMPNAM++;
        my $fh = $class->new;

        sysopen $fh, $tmpfile, $Mode, $Perms
            or die "failed to open $tmpfile: $!";
        $r->pool->cleanup_register(sub { unlink $tmpfile });

        if ($fh) {
            return wantarray ? ($tmpfile, $fh) : $fh;
        }
    }
}

# the following functions now live in Apache2::RequestIO
# * discard_request_body

# the following functions now live in Apache2::Response
# * meets_conditions
# * set_content_length
# * set_etag
# * set_last_modified
# * update_mtime

# the following functions now live in Apache2::RequestRec
# * mtime

package Apache::Util;

sub size_string {
    my ($size) = @_;

    if (!$size) {
        $size = "   0k";
    }
    elsif ($size == -1) {
        $size = "    -";
    }
    elsif ($size < 1024) {
        $size = "   1k";
    }
    elsif ($size < 1048576) {
        $size = sprintf "%4dk", ($size + 512) / 1024;
    }
    elsif ($size < 103809024) {
        $size = sprintf "%4.1fM", $size / 1048576.0;
    }
    else {
        $size = sprintf "%4dM", ($size + 524288) / 1048576;
    }

    return $size;
}

*unescape_uri = \&Apache2::URI::unescape_url;

*escape_path = \&Apache2::Util::escape_path;

sub escape_uri {
    my $path = shift;
    my $r = Apache2::compat::request('Apache2::Util::escape_uri');
    Apache2::Util::escape_path($path, $r->pool);
}

#tmp compat until ap_escape_html is reworked to not require a pool
my %html_escapes = (
    '<' => 'lt',
    '>' => 'gt',
    '&' => 'amp',
    '"' => 'quot',
);

%html_escapes = map { $_, "&$html_escapes{$_};" } keys %html_escapes;

my $html_escape = join '|', keys %html_escapes;

sub escape_html {
    my $html = shift;
    $html =~ s/($html_escape)/$html_escapes{$1}/go;
    $html;
}

*parsedate = \&APR::Date::parse_http;

*validate_password = \&APR::Util::password_validate;

sub Apache2::URI::parse {
    my ($class, $r, $uri) = @_;

    $uri ||= $r->construct_url;

    APR::URI->parse($r->pool, $uri);
}

package Apache::Table;

sub new {
    my ($class, $r, $nelts) = @_;
    $nelts ||= 10;
    APR::Table::make($r->pool, $nelts);
}

package Apache::SIG;

use Apache2::Const -compile => 'DECLINED';

sub handler {
    # don't set the SIGPIPE
    return Apache2::Const::DECLINED;
}

package Apache2::Connection;

# auth_type and user records don't exist in 2.0 conn_rec struct
# 'PerlOptions +GlobalRequest' is required
sub auth_type { shift; Apache2::RequestUtil->request->ap_auth_type(@_) }
sub user      { shift; Apache2::RequestUtil->request->user(@_)      }

1;
__END__
