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
package ModPerl::StructureMap;

use strict;
use warnings FATAL => 'all';
use ModPerl::MapUtil qw(structure_table);

our @ISA = qw(ModPerl::MapBase);

sub new {
    my $class = shift;
    bless {}, $class;
}

sub generate {
    my $self = shift;
    my $map = $self->get;

    for my $entry (@{ structure_table() }) {
        my $type = $entry->{type};
        my $elts = $entry->{elts};

        next unless @$elts;
        next if $type =~ $self->{IGNORE_RE};
        next unless grep {
            not exists $map->{$type}->{ $_->{name} }
        } @$elts;

        print "<$type>\n";
        for my $e (@$elts) {
            print "   $e->{name}\n";
        }
        print "</$type>\n\n";
    }
}

sub disabled { shift->{disabled} }

sub check {
    my $self = shift;
    my $map = $self->get;

    my @missing;

    for my $entry (@{ structure_table() }) {
        my $type = $entry->{type};

        for my $name (map $_->{name}, @{ $entry->{elts} }) {
            next if exists $map->{$type}->{$name};
            next if $type =~ $self->{IGNORE_RE};
            push @missing, "$type.$name";
        }
    }

    return @missing ? \@missing : undef;
}

sub check_exists {
    my $self = shift;

    my %structures;
    for my $entry (@{ structure_table() }) {
        $structures{ $entry->{type} } = { map {
            $_->{name}, 1
        } @{ $entry->{elts} } };
    }

    my @missing;

    while (my ($type, $elts) = each %{ $self->{map} }) {
        for my $name (keys %$elts) {
            next if exists $structures{$type}->{$name};
            push @missing, "$type.$name";
        }
    }

    return @missing ? \@missing : undef;
}

sub parse {
    my ($self, $fh, $map) = @_;

    my ($disabled, $class);
    my %cur;

    while ($fh->readline) {
        if (m:^(\W?)</?([^>]+)>:) {
            my $args;
            $disabled = $1;
            ($class, $args) = split /\s+/, $2, 2;

            %cur = ();
            if ($args and $args =~ /E=/) {
                %cur = $self->parse_keywords($args);
            }

            $self->{MODULES}->{$class} = $cur{MODULE} if $cur{MODULE};

            next;
        }
        elsif (s/^(\w+):\s*//) {
            push @{ $self->{$1} }, split /\s+/;
            next;
        }

        if (s/^(\W)\s*// or $disabled) {
            # < denotes a read-only accessor
            if ($1) {
                if ($1 eq '<') {
                    $map->{$class}->{$_} = 'ro';
                }
                elsif ($1 eq '&') {
                    $map->{$class}->{$_} = 'rw_char_undef';
                }
                elsif ($1 eq '$') {
                    $map->{$class}->{$_} = 'r+w_startup';
                }
                elsif ($1 eq '%') {
                    $map->{$class}->{$_} = 'r+w_startup_dup';
                }
            }
            else {
                $map->{$class}->{$_} = undef;
                push @{ $self->{disabled}->{ $1 || '!' } }, "$class.$_";
            }

        }
        else {
            $map->{$class}->{$_} = 'rw';
        }
    }

    if (my $ignore = $self->{IGNORE}) {
        $ignore = join '|', @$ignore;
        $self->{IGNORE_RE} = qr{^($ignore)};
    }
    else {
        $self->{IGNORE_RE} = qr{^$};
    }
}

sub get {
    my $self = shift;

    $self->{map} ||= $self->parse_map_files;
}

1;
__END__
