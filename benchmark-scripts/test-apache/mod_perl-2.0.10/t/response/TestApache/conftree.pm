# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestApache::conftree;

use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestConfig ();

use Apache2::Directive ();

use Apache2::Const -compile => 'OK';

sub handler {
    my $r = shift;

    my $cfg = Apache::Test::config();

    my $node_count = node_count();

    plan $r, tests => 8 + (5*$node_count);

    ok $cfg;

    my $vars = $cfg->{vars};

    ok $vars;

    my $tree = Apache2::Directive::conftree();

    ok $tree;

    my $hostname_lookups = $tree->lookup('HostnameLookups');

    ok t_cmp($hostname_lookups, "Off");

    my $documentroot = $tree->lookup('DocumentRoot');

    ok t_cmp(ref($tree->as_hash()), 'HASH', 'as_hash');

    ok t_cmp($documentroot, qq("$vars->{documentroot}"));

    ok t_cmp($tree->lookup("DocumentRoot"), qq("$vars->{documentroot}"));

    #XXX: This test isn't so good, but its quite problematic to try
    #and _really_ compare $cfg and $tree...
    {
        my %vhosts = map {
            $cfg->{vhosts}{$_}{name} => { %{$cfg->{vhosts}{$_}}, index => $_ }
        } keys %{$cfg->{vhosts}};

        for my $v (keys %vhosts) {
            $vhosts{ $vhosts{$v}{index} }  = $vhosts{$v};
        }

        my $vhost_failed;
        for my $vhost ($tree->lookup("VirtualHost")) {
            unless (exists $vhosts{$vhost->{'ServerName'}
                || $vhost->{'PerlProcessConnectionHandler'}}) {
                $vhost_failed++;
            }
        }

        ok !$vhost_failed;
    }

    traverse_tree ( \&test_node );

    Apache2::Const::OK;
}

sub test_node {
    my ($data, $node) = @_;
    ok $node->directive;
    #Args can be null for argless directives
    ok $node->args || 1;
    #As string can be null for containers
    ok $node->as_string || 1;
    ok $node->filename;
    ok $node->line_num;
}

sub traverse_tree {
    my ($sub, $data) = @_;
    my $node = Apache2::Directive::conftree();
    while ($node) {
        $sub->($data, $node);
        if (my $kid = $node->first_child) {
            $node = $kid;
        }
        elsif (my $next = $node->next) {
            $node = $next;
        }
        else {
            if (my $parent = $node->parent) {
                $node = $parent->next;
            }
            else {
                $node = undef;
            }
        }
    }
    return;
}

sub node_count {
    my $node_count = 0;

    traverse_tree( sub { ${$_[0]}++ }, \$node_count );

    return $node_count;
}
1;
