# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestDirective::perlloadmodule;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestTrace;

use Apache2::Const -compile => qw(OK OR_ALL RSRC_CONF TAKE1 TAKE23);

use Apache2::CmdParms ();
use Apache2::Module ();

my @directives = (
    {
     name => 'MyTest',
     func => __PACKAGE__ . '::MyTest',
     req_override => Apache2::Const::RSRC_CONF,
#     req_override => 'RSRC_CONF', #test 1.x compat for strings
#     args_how => Apache2::Const::TAKE23,
     args_how => 'TAKE23', #test 1.x compat for strings
     errmsg => 'A test',
    },
    {
     name => 'MyOtherTest',
     cmd_data => 'some info',
    },
    {
     name => 'ServerTest',
     req_override => Apache2::Const::RSRC_CONF,
    }
);

Apache2::Module::add(__PACKAGE__, \@directives);

sub DIR_CREATE {
    my ($class, $parms) = @_;

    bless {
        path => $parms->path || "/",
    }, $class;
}

sub merge {
    my ($base, $add) = @_;

    my %new = ();

    @new{keys %$base, keys %$add} =
        (values %$base, values %$add);

    return bless \%new, ref($base);
}

sub DIR_MERGE {
    my $class = ref $_[0];
    debug "$class->DIR_MERGE\n";
    merge(@_);
}

#sub SERVER_MERGE {
#    my $class = ref $_[0];
#    debug "$class->SERVER_MERGE\n";
#    merge(@_);
#}

sub SERVER_CREATE {
    my ($class, $parms) = @_;
    debug "$class->SERVER_CREATE\n";
    return bless {
        name => __PACKAGE__,
    }, $class;
}

sub MyTest {
    my ($self, $parms, @args) = @_;
    $self->{MyTest} = \@args;
    $self->{MyTestInfo} = $parms->info;
}

sub MyOtherTest {
    my ($self, $parms, $arg) = @_;
    $self->{MyOtherTest} = $arg;
    $self->{MyOtherTestInfo} = $parms->info;
}

sub ServerTest {
    my ($self, $parms, $arg) = @_;
    my $srv_cfg = $self->get_config($parms->server);
    $srv_cfg->{ServerTest} = $arg;
}

sub get_config {
    my ($self, $s) = (shift, shift);
    Apache2::Module::get_config($self, $s, @_);
}

sub handler : method {
    my ($self, $r) = @_;

    my $s = $r->server;
    my $dir_cfg = $self->get_config($s, $r->per_dir_config);
    my $srv_cfg = $self->get_config($s);

    plan $r, tests => 9;

    t_debug("per-dir config:", $dir_cfg);
    t_debug("per-srv config:", $srv_cfg);

    ok $dir_cfg->isa($self);
    ok $srv_cfg->isa($self);

    my $path = $dir_cfg->{path};

    ok t_cmp($r->uri, qr{^$path},
             'r->uri =~ parms->path');

    ok t_cmp($srv_cfg->{name}, $self,
             '$self eq $srv_cfg->{name}');

    ok t_cmp($dir_cfg->{MyOtherTest}, 'value',
             'MyOtherTest value');

    ok t_cmp($dir_cfg->{MyOtherTestInfo}, 'some info',
             'MyOtherTest cmd_data');

    ok t_cmp($dir_cfg->{MyTest}, ['one', 'two'],
             'MyTest one two');

    ok ! $dir_cfg->{MyTestInfo};

    ok t_cmp($srv_cfg->{ServerTest}, 'per-server');

    Apache2::Const::OK;
}

1;
__END__

# APACHE_TEST_CONFIG_ORDER 950

<Base>
    PerlLoadModule TestDirective::perlloadmodule

    MyTest one two
    ServerTest per-server
</Base>

MyOtherTest value

