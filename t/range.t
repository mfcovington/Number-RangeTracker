#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Test::More tests => 8;

BEGIN{ use_ok('range'); }

my %range = ();

is( range_length(\%range), 0, 'get range length before adding ranges');

add_range( 10, 20, \%range );

is_deeply( \%range, { 10 => 20, }, 'add initial range' );

subtest 'add additional ranges' => sub {
    plan tests => 5;

    add_range( 15, 30, \%range );
    add_range( 7,  11, \%range );
    is_deeply(
        \%range,
        {
            7  => 11,
            10 => 20,
            15 => 30,
        },
        'add left & right overlapping ranges'
    );

    add_range( 4,  6,  \%range );
    add_range( 31, 35, \%range );
    is_deeply(
        \%range,
        {
            4  => 6,
            7  => 11,
            10 => 20,
            15 => 30,
            31 => 35,
        },
        'add left & right adjacent ranges'
    );

    add_range( 32, 34, \%range );
    is_deeply(
        \%range,
        {
            4  => 6,
            7  => 11,
            10 => 20,
            15 => 30,
            31 => 35,
            32 => 34,
        },
        'add subrange'
    );

    add_range( 10, 13, \%range );
    is_deeply(
        \%range,
        {
            4  => 6,
            7  => 11,
            10 => 20,
            15 => 30,
            31 => 35,
            32 => 34,
        },
        'add subrange that shares start'
    );

    add_range( 7, 15, \%range );
    is_deeply(
        \%range,
        {
            4  => 6,
            7  => 15,
            10 => 20,
            15 => 30,
            31 => 35,
            32 => 34,
        },
        'add super-range that shares start'
    );
};

collapse_ranges( \%range );
is_deeply( \%range, { 4 => 35, }, 'collapse overlapping ranges' );

subtest 'add additional ranges after collapse_ranges' => sub {
    plan tests => 4;

    add_range( 40, 50, \%range );
    is_deeply(
        \%range,
        {
            4  => 35,
            40 => 50,
        },
        'add non-overlapping range'
    );

    add_range( -20, -10, \%range );
    is_deeply(
        \%range,
        {
            -20 => -10,
            4   => 35,
            40  => 50,
        },
        'add negative range'
    );

    add_range( -20, -10, \%range );
    is_deeply(
        \%range,
        {
            -20 => -10,
            4   => 35,
            40  => 50,
        },
        'add subrange'
    );

    add_range( -2, 2, \%range );
    is_deeply(
        \%range,
        {
            -20 => -10,
            -2  => 2,
            4   => 35,
            40  => 50,
        },
        'add range that crosses zero'
    );
};

subtest 'test is_in_range' => sub {
    plan tests => 5;

    add_range( -2, 4, \%range );
    my @rangecheck = is_in_range( -3, \%range);
    is_deeply( \@rangecheck, [0], 'check value out of range (too small)' );

    @rangecheck = is_in_range( 36, \%range);
    is_deeply( \@rangecheck, [0], 'check value out of range (too large)' );

    @rangecheck = is_in_range( -2, \%range);
    is_deeply( \@rangecheck, [ 1, -2, 35 ], 'check value in range (left edge)' );

    @rangecheck = is_in_range( 0, \%range);
    is_deeply( \@rangecheck, [ 1, -2, 35 ], 'check value in range (interior)' );

    @rangecheck = is_in_range( 35, \%range);
    is_deeply( \@rangecheck, [ 1, -2, 35 ], 'check value in range (right edge)' );
};

add_range( 51, 55, \%range );
my $length = range_length( \%range );
is( $length, 65, 'range length' );
