# please insert nothing before this line: -*- mode: cperl; cperl-indent-level: 4; cperl-continued-statement-offset: 4; indent-tabs-mode: nil -*-
package TestPerl::hash_attack;

# if the rehashing of the keys in the stash happens due to the hash attack,
# mod_perl must not fail to find the previously cached stash entry (response
# and fixup handlers in this test). Moreover it must not fail to find
# that entry on the subsequent requests.
#
# the hash attack is detected when HV_MAX_LENGTH_BEFORE_REHASH keys find
# themselves in the same hash bucket on splitting (which happens when the
# number of keys crosses the threshold of a power of 2), in which case
# starting from 5.8.2 the hash will rehash all its keys using a random hash
# seed (PL_new_hash_seed, set in mod_perl or via PERL_HASH_SEED environment
# variable)
#
# Prior to the attack condition hashes use the PL_hash_seed, which is
# always 0.
#
# only in 5.8.1 hashes always use a non-zero PL_hash_seed (unless set
# to 0 via PERL_HASH_SEED environment variable or compiled without
# -DUSE_HASH_SEED or -DUSE_HASH_SEED_EXPLICIT

use strict;
use warnings FATAL => 'all';

use Apache::TestTrace;

use Apache2::Const -compile => 'OK';

use Math::BigInt;

use constant MASK_U32  => 2**32;
use constant HASH_SEED => 0; # 5.8.2: always zero before the rehashing
use constant THRESHOLD => 14; #define HV_MAX_LENGTH_BEFORE_(SPLIT|REHASH)
use constant START     => "a";

# create conditions which will trigger a rehash on the current stash
# (__PACKAGE__::). Relevant for perl 5.8.2 and higher.
sub init {
    my $r = shift;

    no strict 'refs';
    my @attack_keys = attack(\%{__PACKAGE__ . "::"}) if $] >= 5.008002;

    # define a new symbol (sub) after the attack has caused a re-hash
    # check that mod_perl finds that symbol (fixup2) in the stash
    no warnings 'redefine';
    eval qq[sub fixup2 { return Apache2::Const::OK; }];
    $r->push_handlers(PerlFixupHandler => \&fixup2);

    return Apache2::Const::DECLINED;
}

sub fixup { return Apache2::Const::OK; }

sub handler {
    my $r = shift;
    $r->print("ok");
    return Apache2::Const::OK;
}

sub buckets { scalar(%{$_[0]}) =~ m#/([0-9]+)\z# ? 0+$1 : 8 }

sub attack {
    my $stash = shift;

    #require Hash::Util; # avail since 5.8.0
    debug "starting attack (it may take a long time!)";

    my @keys;

    # the minimum of bits required to mount the attack on a hash
    my $min_bits = log(THRESHOLD)/log(2);

    # if the hash has already been populated with a significant amount
    # of entries the number of mask bits can be higher
    my $keys = scalar keys %$stash;
    my $bits = $keys ? log($keys)/log(2) : 0;
    $bits = $min_bits if $min_bits > $bits;

    $bits = ceil($bits);
    # need to add 3 bits to cover the internal split cases
    $bits += 3;
    my $mask = 2**$bits-1;
    debug "mask: $mask ($bits)";

    my $s = START;
    my $c = 0;
    # get 2 keys on top of the THRESHOLD
    my $h;
    while (@keys < THRESHOLD+2) {
        next if exists $stash->{$s};
        $h = hash($s);
        next unless ($h & $mask) == 0;
        $c++;
        $stash->{$s}++;
        debug sprintf "%2d: %5s, %08x %s", $c, $s, $h, scalar(%$stash);
        push @keys, $s;
        debug "The hash collision attack has been successful"
            if Internals::HvREHASH(%$stash);
    } continue {
        $s++;
    }

    # If the rehash hasn't been triggered yet, it's being delayed until the
    # next bucket split.  Add keys until a split occurs.
    unless (Internals::HvREHASH(%$stash)) {
        debug "Will add padding keys until hash split";
        my $old_buckets = buckets($stash);
        while (buckets($stash) == $old_buckets) {
            next if exists $stash->{$s};
            $h = hash($s);
            $c++;
            $stash->{$s}++;
            debug sprintf "%2d: %5s, %08x %s", $c, $s, $h, scalar(%$stash);
            push @keys, $s;
            debug "The hash collision attack has been successful"
                if Internals::HvREHASH(%$stash);
            $s++;
        }
    }

    # this verifies that the attack was mounted successfully. If
    # HvREHASH is on it is. Otherwise the sequence wasn't successful.
    die "Failed to mount the hash collision attack"
        unless Internals::HvREHASH(%$stash);

    debug "ending attack";

    return @keys;
}

# least integer >= n
sub ceil {
    my $value = shift;
    return int($value) < $value ? int($value) + 1 : int($value);
}

# trying to provide the fastest equivalent of C macro's PERL_HASH in
# Perl - the main complication is that the C macro uses U32 integer
# (unsigned int), which we can't do it Perl (it can do I32, with 'use
# integer'). So we outsmart Perl and take modules 2*32 after each
# calculation, emulating overflows that happen in C.
sub hash {
    my $s = shift;
    my @c = split //, $s;
    my $u = HASH_SEED;
    for (@c) {
        # (A % M) + (B % M) == (A + B) % M
        # This works because '+' produces a NV, which is big enough to hold
        # the intermidiate result. We only need the % before any "^" and "&"
        # to get the result in the range for an I32.
        # and << doesn't work on NV, so using 1 << 10
        $u += ord;
        $u += $u * (1 << 10); $u %= MASK_U32;
        $u ^= $u >> 6;
    }
    $u += $u << 3;  $u %= MASK_U32;
    $u ^= $u >> 11; $u %= MASK_U32;
    $u += $u << 15; $u %= MASK_U32;
    $u;
}

# a bit slower but simpler version
sub hash_original {
    my $s = shift;
    my @c = split //, $s;
    my $u = HASH_SEED;
    for (@c) {
        $u += ord;      $u %= MASK_U32;
        $u += $u << 10; $u %= MASK_U32;
        $u ^= $u >> 6;  $u %= MASK_U32;
    }
    $u += $u << 3;  $u %= MASK_U32;
    $u ^= $u >> 11; $u %= MASK_U32;
    $u += $u << 15; $u %= MASK_U32;
    $u;
}

1;

__END__
PerlModule       TestPerl::hash_attack
PerlInitHandler  TestPerl::hash_attack::init
# call twice to verify an access to the same hash value after the rehash
PerlFixupHandler TestPerl::hash_attack::fixup TestPerl::hash_attack::fixup

