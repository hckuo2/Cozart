# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestDirective::perlloadmodule2;

# in this test the merge is inherits all the values from the ancestors
# and adds new values if such were set

use strict;
use warnings FATAL => 'all';

use Apache2::Const -compile => qw(OK OR_ALL ITERATE);

use Apache2::CmdParms ();
use Apache2::Module ();

my @directives = (
    {
     name         => 'MyMergeTest',
     func         => __PACKAGE__ . '::MyMergeTest',
     req_override => Apache2::Const::OR_ALL,
     args_how     => Apache2::Const::ITERATE,
     errmsg       => 'Values that get merged',
    },
);

Apache2::Module::add(__PACKAGE__, \@directives);

sub merge {
    my ($base, $add) = @_;

    my %new = ();

    # be careful if the object values are references and not scalars.
    # If that's the case a deep copy must be performed, or the merged
    # object will affect the based object, which will break things
    # when DIR_MERGE is called twice for the same $base/$add during
    # the same request
    push @{ $new{$_} }, @{ $base->{$_}||[] } for keys %$base;
    push @{ $new{$_} }, @{ $add->{$_} ||[] } for keys %$add;

    return bless \%new, ref($base);
}

sub DIR_MERGE {
    my $class = ref $_[0];
    #warn "$class->DIR_MERGE\n";
    merge(@_);
}

sub SERVER_MERGE {
    my $class = ref $_[0];
    #warn "$class->SERVER_MERGE\n";
    merge(@_);
}

# this variable is of type ITERATE, so it'll get called as many times
# as arguments, a single argument at a time. This function is called
# only during the server startup and when the directive appears in the
# .htaccess files
sub MyMergeTest {
    my ($self, $parms, $arg) = @_;
    #warn "MyMergeTest: @{[$parms->path||'']}\n\t$arg\n";
    push @{ $self->{MyMergeTest} }, $arg;

    # store the top level srv values in the server struct as well, so
    # during the request you can query what was the top level (srv)
    # setting, before it was merged with the current container's
    # setting if any
    unless ($parms->path) {
        my $srv_cfg = $self->get_config($parms->server);
        push @{ $srv_cfg->{MyMergeTest} }, $arg;
    }
}

sub get_config {
    my ($self, $s) = (shift, shift);
    Apache2::Module::get_config($self, $s, @_);
}

sub handler : method {
    my ($self, $r) = @_;

    $r->content_type('text/plain');

    my $s = $r->server;

    if (defined $r->args and $r->args eq 'srv') {
        my $srv_cfg = $self->get_config($s);
        $r->print("srv: @{ $srv_cfg->{MyMergeTest}||[] }");
    }
    else {
        my $dir_cfg = $self->get_config($s, $r->per_dir_config);
        $r->print("dir: @{ $dir_cfg->{MyMergeTest}||[] }");
    }

    return Apache2::Const::OK;
}

1;
__END__

# APACHE_TEST_CONFIG_ORDER 950

<Base>
    PerlLoadModule TestDirective::perlloadmodule2

    MyMergeTest one two
</Base>
<Location /TestDirective__perlloadmodule2>
    MyMergeTest three four
</Location>
<Location /TestDirective__perlloadmodule2/subdir>
   MyMergeTest five
   MyMergeTest six
</Location>
