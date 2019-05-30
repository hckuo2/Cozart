# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestDirective::perlloadmodule3;

# in this test we test various merging techniques. As a side effect it
# tests how mod_perl works when its forced to start early outside
# vhosts and how it works with vhosts. See perlloadmodule4.pm and
# perlloadmodule5.pm, for similar tests that starts mod_perl early
# from a vhost.

use strict;
use warnings FATAL => 'all';

use Apache2::CmdParms ();
use Apache2::Module ();
use Apache2::ServerUtil ();

use Apache2::Const -compile => qw(OK);


my @directives = (
    { name => 'MyPlus' },
    { name => 'MyList' },
    { name => 'MyAppend' },
    { name => 'MyOverride' },
);

Apache2::Module::add(__PACKAGE__, \@directives);

sub MyPlus     { set_val('MyPlus',     @_) }
sub MyAppend   { set_val('MyAppend',   @_) }
sub MyOverride { set_val('MyOverride', @_) }
sub MyList     { push_val('MyList',    @_) }

sub DIR_MERGE    { merge(@_) }
sub SERVER_MERGE { merge(@_) }

sub set_val {
    my ($key, $self, $parms, $arg) = @_;
    $self->{$key} = $arg;
    unless ($parms->path) {
        my $srv_cfg = Apache2::Module::get_config($self, $parms->server);
        $srv_cfg->{$key} = $arg;
    }
}

sub push_val {
    my ($key, $self, $parms, $arg) = @_;
    push @{ $self->{$key} }, $arg;
    unless ($parms->path) {
        my $srv_cfg = Apache2::Module::get_config($self, $parms->server);
        push @{ $srv_cfg->{$key} }, $arg;
    }
}

sub merge {
    my ($base, $add) = @_;

    my %mrg = ();
    for my $key (keys %$base, %$add) {
        next if exists $mrg{$key};
        if ($key eq 'MyPlus') {
            $mrg{$key} = ($base->{$key}||0) + ($add->{$key}||0);
        }
        elsif ($key eq 'MyList') {
            push @{ $mrg{$key} },
                @{ $base->{$key}||[] }, @{ $add->{$key}||[] };
        }
        elsif ($key eq 'MyAppend') {
            $mrg{$key} = join " ", grep defined, $base->{$key}, $add->{$key};
        }
        else {
            # override mode
            $mrg{$key} = $base->{$key} if exists $base->{$key};
            $mrg{$key} = $add->{$key}  if exists $add->{$key};
        }
    }

    return bless \%mrg, ref($base);
}

### response handler ###


use Apache2::RequestRec ();
use Apache2::RequestIO ();
use Apache2::ServerRec ();
use Apache2::ServerUtil ();
use Apache2::Module ();

use Apache2::Const -compile => qw(OK);

sub get_config {
    Apache2::Module::get_config(__PACKAGE__, @_);
}

sub handler {
    my ($r) = @_;
    my %secs = ();

    $r->content_type('text/plain');

    my $s = $r->server;
    my $dir_cfg = get_config($s, $r->per_dir_config);
    my $srv_cfg = get_config($s);

    if ($s->is_virtual) {
        $secs{"1: Main Server"}  = get_config(Apache2::ServerUtil->server);
        $secs{"2: Virtual Host"} = $srv_cfg;
        $secs{"3: Location"}     = $dir_cfg;
    }
    else {
        $secs{"1: Main Server"}  = $srv_cfg;
        $secs{"2: Location"}     = $dir_cfg;
     }

    $r->printf("Processing by %s.\n",
        $s->is_virtual ? "virtual host" : "main server");

    for my $sec (sort keys %secs) {
        $r->print("\nSection $sec\n");
        for my $k (sort keys %{ $secs{$sec}||{} }) {
            my $v = exists $secs{$sec}->{$k} ? $secs{$sec}->{$k} : 'UNSET';
            $v = '[' . (join ", ", map {qq{"$_"}} @$v) . ']'
                if ref($v) eq 'ARRAY';
            $r->printf("%-10s : %s\n", $k, $v);
        }
    }

    return Apache2::Const::OK;
}



1;
__END__

# APACHE_TEST_CONFIG_ORDER 950

<Base>
    PerlLoadModule TestDirective::perlloadmodule3
    MyPlus 5
    MyList     "MainServer"
    MyAppend   "MainServer"
    MyOverride "MainServer"
</Base>
<VirtualHost TestDirective::perlloadmodule3>
    MyPlus 2
    MyList     "VHost"
    MyAppend   "VHost"
    MyOverride "VHost"
    <Location /TestDirective__perlloadmodule3>
        MyPlus 3
        MyList     "Dir"
        MyAppend   "Dir"
        MyOverride "Dir"
        SetHandler modperl
        PerlResponseHandler TestDirective::perlloadmodule3
    </Location>
    <Location /TestDirective__perlloadmodule3/subdir>
        MyPlus 1
        MyList     "SubDir"
        MyAppend   "SubDir"
        MyOverride "SubDir"
    </Location>
</VirtualHost>
