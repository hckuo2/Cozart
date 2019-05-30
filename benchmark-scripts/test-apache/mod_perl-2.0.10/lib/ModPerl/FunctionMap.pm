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
package ModPerl::FunctionMap;

use strict;
use warnings FATAL => 'all';
use ModPerl::MapUtil qw();
use ModPerl::ParseSource ();

our @ISA = qw(ModPerl::MapBase);

sub new {
    my $class = shift;
    bless {}, $class;
}

#for adding to function.map
sub generate {
    my $self = shift;

    my $missing = $self->check;
    return unless $missing;

    print " $_\n" for @$missing;
}

sub disabled { shift->{disabled} }

#look for functions that do not exist in *.map
sub check {
    my $self = shift;
    my $map = $self->get;

    my @missing;
    my $mp_func = ModPerl::ParseSource->wanted_functions;

    for my $name (map $_->{name}, @{ $self->function_table() }) {
        next if exists $map->{$name};
        push @missing, $name unless $name =~ /^($mp_func)/o;
    }

    return @missing ? \@missing : undef;
}

#look for functions in *.map that do not exist
my $special_name = qr{(^DEFINE_|DESTROY$)};

sub check_exists {
    my $self = shift;

    my %functions = map { $_->{name}, 1 } @{ $self->function_table() };
    my @missing = ();

    for my $name (keys %{ $self->{map} }) {
        next if $functions{$name};
        push @missing, $name unless $name =~ $special_name;
    }

    return @missing ? \@missing : undef;
}

my $keywords = join '|', qw(MODULE PACKAGE PREFIX BOOT);

sub guess_prefix {
    my $entry = shift;

    my ($name, $class) = ($entry->{name}, $entry->{class});
    my $prefix = "";
    $name =~ s/^DEFINE_//;
    $name =~ s/^mpxs_//i;

    (my $modprefix = ($entry->{class} || $entry->{module}) . '_') =~ s/::/__/g;
    (my $guess = lc $modprefix) =~ s/_+/_/g;

    $guess =~ s/(apache2)_/($1|ap)_{1,2}/;

    if ($name =~ s/^($guess|$modprefix).*/$1/i) {
        $prefix = $1;
    }
    else {
        if ($name =~ /^(apr?_)/) {
            $prefix = $1;
        }
    }

    #print "GUESS prefix=$guess, name=$entry->{name} -> $prefix\n";

    return $prefix;
}

sub parse {
    my ($self, $fh, $map) = @_;
    my %cur;
    my $disabled = 0;

    while ($fh->readline) {
        if (/($keywords)=/o) {
            $disabled = s/^\W//; #module is disabled
            my %words = $self->parse_keywords($_);

            if ($words{MODULE}) {
                %cur = ();
            }

            if ($words{PACKAGE}) {
                delete $cur{CLASS};
            }

            for (keys %words) {
                $cur{$_} = $words{$_};
            }

            next;
        }

        my ($name, $dispatch, $argspec, $alias) = split /\s*\|\s*/;
        my $return_type;

        if ($name =~ s/^([^:]+)://) {
            $return_type = $1;
            $return_type =~ s/\s+$//;  # allow: char *    :....
        }

        if ($name =~ s/^(\W)// or not $cur{MODULE} or $disabled) {
            #notimplemented or cooked by hand
            die qq[function '$name' appears more than once in xs/maps files]
                if $map->{$name};

            $map->{$name} = undef;
            push @{ $self->{disabled}->{ $1 || '!' } }, $name;
            next;
        }

        if (my $package = $cur{PACKAGE}) {
            unless ($package eq 'guess') {
                $cur{CLASS} = $package;
            }
            if ($cur{ISA}) {
                $self->{isa}->{ $cur{MODULE} }->{$package} = delete $cur{ISA};
            }
            if ($cur{BOOT}) {
                $self->{boot}->{ $cur{MODULE} } = delete $cur{BOOT};
            }
        }
        else {
            $cur{CLASS} = $cur{MODULE};
        }

        #XXX: make_prefix() stuff should be here, not ModPerl::WrapXS
        if ($name =~ /^DEFINE_/ and $cur{CLASS}) {
            $name =~ s{^(DEFINE_)(.*)}
              {$1 . ModPerl::WrapXS::make_prefix($2, $cur{CLASS})}e;
        }

        die qq[function '$name' appears more than once in xs/maps files]
            if $map->{$name};

        my $entry = $map->{$name} = {
           name        => $alias || $name,
           dispatch    => $dispatch,
           argspec     => $argspec ? [split /\s*,\s*/, $argspec] : "",
           return_type => $return_type,
           alias       => $alias,
        };

        for (keys %cur) {
            $entry->{lc $_} = $cur{$_};
        }

        #avoid 'use of uninitialized value' warnings
        $entry->{$_} ||= "" for keys %{ $entry };
        if ($entry->{dispatch} =~ /_$/) {
            $entry->{dispatch} .= $name;
        }
    }
}

sub get {
    my $self = shift;

    $self->{map} ||= $self->parse_map_files;
}

sub prefixes {
    my $self = shift;
    $self = ModPerl::FunctionMap->new unless ref $self;

    my $map = $self->get;
    my %prefix;

    while (my ($name, $ent) = each %$map) {
        next unless $ent->{prefix};
        $prefix{ $ent->{prefix} }++;
    }

    $prefix{$_} = 1 for qw(ap_ apr_); #make sure we get these

    [keys %prefix]
}

1;
__END__
