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
package Apache2::PerlSections::Dump;

use strict;
use warnings FATAL => 'all';

our $VERSION = '0.01';

use Apache2::PerlSections;
our @ISA = qw(Apache2::PerlSections);

use Data::Dumper;

# Process all saved packages
sub package     { return shift->saved }

# We don't want to save anything
sub save        { return }

# We don't want to post any config to apache, we are dumping
sub post_config { return }

sub dump {
    my $self = shift;
    unless (ref $self) {
        $self = $self->new;
    }
    $self->handler();
    return join "\n", @{$self->directives}, '1;', '__END__', '';
}

sub store {
    my ($class, $filename) = @_;
    require IO::File;

    my $fh = IO::File->new(">$filename") or die "can't open $filename $!\n";

    $fh->print($class->dump);

    $fh->close;
}

sub dump_array {
     my ($self, $name, $entry) = @_;
     $self->add_config(Data::Dumper->Dump([$entry], ["*$name"]));
}

sub dump_hash {
    my ($self, $name, $entry) = @_;
    for my $elem (sort keys %{$entry}) {
        $self->add_config(Data::Dumper->Dump([$entry->{$elem}],
                                             ["\$$name"."{'$elem'}"]));
    }

}

sub dump_entry {
    my ($self, $name, $entry) = @_;

    return if not defined $entry;
    my $type = ref($entry);

    if ($type eq 'SCALAR') {
        $self->add_config(Data::Dumper->Dump([$$entry],[$name]));
    }
    if ($type eq 'ARRAY') {
        $self->dump_array($name,$entry);
    }
    else {
        $self->add_config(Data::Dumper->Dump([$entry],[$name]));
    }
}

sub dump_special {
    my ($self, @data) = @_;

    my @dump = grep { defined } @data;
    return unless @dump;

    $self->add_config(Data::Dumper->Dump([\@dump],['*'.$self->SPECIAL_NAME]));
}



1;
__END__
