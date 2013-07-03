#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Data::Printer;
use Test::More tests => 5;

my $debug = 0;

BEGIN { use_ok( 'range_oo 0.2.1', ':ALL' ); }

use feature 'say';    # temporarily...

my $range = range_oo->new();

my @ranges = (
    [ -20, -10 ],
    [ -5,  5 ],
    [ 10,  20 ],
    [ 40,  50 ],
    [ 80,  90 ],
    [ 85,  100 ],
    [ 120, 150 ],
    [ 200, 250 ]
);
for ( @ranges) {
    my ($start, $end) = @$_;
    $range->add_range_oo( $start, $end );
}
is_deeply(
    $range,
    {
        add   => { -20 => -10, -5 => 5, 10 => 20, 40 => 50, 80 => 90, 85 => 100, 120 => 150, 200 => 250 },
        rm    => {},
        messy => 1
    },
    'add 8 initial ranges'
);

subtest 'range check' => sub {
    plan tests => 8;

    my @in_range_neg   = $range->is_in_range_oo(-15);
    my @in_range_left  = $range->is_in_range_oo(40);
    my @in_range_mid   = $range->is_in_range_oo(45);
    my @in_range_right = $range->is_in_range_oo(50);
    my @out_before     = $range->is_in_range_oo(-30);
    my @out_mid        = $range->is_in_range_oo(105);
    my @out_after      = $range->is_in_range_oo(300);

    is_deeply( \@in_range_neg,   [ 1, -20, -10 ], 'value in range (left border)' );
    is_deeply( \@in_range_left,  [ 1, 40,  50 ],  'value in range (left border)' );
    is_deeply( \@in_range_mid,   [ 1, 40,  50 ],  'value in range (middle)' );
    is_deeply( \@in_range_right, [ 1, 40,  50 ],  'value in range (right border)' );
    is_deeply( \@out_before, [0], 'value out of range (before all)' );
    is_deeply( \@out_mid,    [0], 'value out of range (interior)' );
    is_deeply( \@out_after,  [0], 'value out of range (after all)' );

    is_deeply(
        $range,
        {
            add   => { -20 => -10, -5 => 5, 10 => 20, 40 => 50, 80 => 100, 120 => 150, 200 => 250 },
            rm    => {},
            messy => 0
        },
        'ranges collapsed during is_in_range check'
    );
};

@ranges = ( [ 0, 44 ], [ 131, 139 ], [ 241, 300 ] );
for (@ranges) {
    my ( $start, $end ) = @$_;
    $range->rm_range_oo( $start, $end );
}
is_deeply(
    $range,
    {
        add   => { -20 => -10, -5 => 5, 10 => 20, 40  => 50,  80  => 100, 120 => 150, 200 => 250 },
        rm    => { 0 => 44, 131 => 139, 241 => 300 },
        messy => 1
    },
    'remove 3 ranges'
);

subtest 'range length' => sub {
    plan tests => 2;

    my $length = $range->range_length_oo;
    is( $length, 106, 'range length' );
    is_deeply(
        $range,
        {
            add   => { -20 => -10, -5 => -1, 45 => 50, 80 => 100, 120 => 130, 140 => 150, 200 => 240 },
            rm    => {},
            messy => 0
        },
        'ranges collapsed during range_length'
    );
};

__END__
subtest 'output ranges' => sub {
    plan tests => 2;

    add_range( 300,  400,  \%range );
    my $scalar_out = output_ranges( \%range );
    is( $scalar_out, '-20..-10,-5..-1,45..50,80..100,120..130,140..150,200..240,300..400', 'output range string');

    add_range( 500,  600,  \%range );
    my %hash_out = output_ranges( \%range );
    is_deeply(
        \%hash_out,
        { -20 => -10, -5 => -1, 45 => 50, 80 => 100, 120 => 130, 140 => 150, 200 => 240, 300 => 400, 500 => 600 },
        'output range hash'
    );
};

subtest 'output integers in range' => sub {
    plan tests => 2;

    rm_range( 45,  600,  \%range );
    my $scalar_out = output_integers( \%range );
    is( $scalar_out, '-20,-19,-18,-17,-16,-15,-14,-13,-12,-11,-10,-5,-4,-3,-2,-1', 'output integers string');

    rm_range( -20, -10, \%range );
    add_range( 5, 10, \%range );
    my @array_out = output_integers( \%range );
    is_deeply(
        \@array_out,
        [ -5, -4, -3, -2, -1, 5, 6, 7, 8, 9, 10 ],
        'output integers array'
    );
};

my $test_name;
my $start;
my $end;
my $range_ref;

subtest 'add various ranges' => sub {
    plan tests => 22;

    $start     = 5;
    $end       = 8;
    $test_name = "add + collapse range ($start - $end) that ends before 1st";
    $range_ref = { add => { 5 => 8, 10 => 20, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 5;
    $end       = 15;
    $test_name = "add + collapse range ($start - $end) that begins before 1st and ends in 1st";
    $range_ref = { add => { 5 => 20, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 5;
    $end       = 25;
    $test_name = "add + collapse range ($start - $end) that begins before 1st and ends between 1st and 2nd";
    $range_ref = { add => { 5 => 25, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 5;
    $end       = 45;
    $test_name = "add + collapse range ($start - $end) that begins before 1st and ends in 2nd";
    $range_ref = { add => { 5 => 50, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 5;
    $end       = 60;
    $test_name = "add + collapse range ($start - $end) that begins before 1st and ends between 2nd and 3rd";
    $range_ref = { add => { 5 => 60, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 5;
    $end       = 90;
    $test_name = "add + collapse range ($start - $end) that begins before 1st and ends in 3rd";
    $range_ref = { add => { 5 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 15;
    $end       = 20;
    $test_name = "add + collapse range ($start - $end) that begins in 1st and ends in 1st";
    $range_ref = { add => { 10 => 20, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 15;
    $end       = 25;
    $test_name = "add + collapse range ($start - $end) that begins in 1st and ends between 1st and 2nd";
    $range_ref = { add => { 10 => 25, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 15;
    $end       = 45;
    $test_name = "add + collapse range ($start - $end) that begins in 1st and ends in 2nd";
    $range_ref = { add => { 10 => 50, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 15;
    $end       = 60;
    $test_name = "add + collapse range ($start - $end) that begins in 1st and ends between 2nd and 3rd";
    $range_ref = { add => { 10 => 60, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 15;
    $end       = 90;
    $test_name = "add + collapse range ($start - $end) that begins in 1st and ends in 3rd";
    $range_ref = { add => { 10 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 25;
    $end       = 30;
    $test_name = "add + collapse range ($start - $end) that begins between 1st and 2nd and ends before 2nd";
    $range_ref = { add => { 10 => 20, 25 => 30, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 25;
    $end       = 45;
    $test_name = "add + collapse range ($start - $end) that begins between 1st and 2nd and ends in 2nd";
    $range_ref = { add => { 10 => 20, 25 => 50, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 25;
    $end       = 60;
    $test_name = "add + collapse range ($start - $end) that begins between 1st and 2nd and ends between 2nd and 3rd";
    $range_ref = { add => { 10 => 20, 25 => 60, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 25;
    $end       = 90;
    $test_name = "add + collapse range ($start - $end) that begins between 1st and 2nd and ends in 3rd";
    $range_ref = { add => { 10 => 20, 25 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 5;
    $end       = 9;
    $test_name = "add + collapse range ($start - $end) adjacent to next range (first range)";
    $range_ref = { add => { 5 => 20, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 25;
    $end       = 39;
    $test_name = "add + collapse range ($start - $end) adjacent to next range (middle range)";
    $range_ref = { add => { 10 => 20, 25 => 50, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 190;
    $end       = 199;
    $test_name = "add + collapse range ($start - $end) adjacent to next range (last range)";
    $range_ref = { add => { 10 => 20, 40 => 50, 80 => 100, 120 => 150, 190 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 21;
    $end       = 25;
    $test_name = "add + collapse range ($start - $end) adjacent to previous range (first range)";
    $range_ref = { add => { 10 => 25, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 51;
    $end       = 60;
    $test_name = "add + collapse range ($start - $end) adjacent to previous range (middle range)";
    $range_ref = { add => { 10 => 20, 40 => 60, 80 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 251;
    $end       = 300;
    $test_name = "add + collapse range ($start - $end) adjacent to previous range (last range)";
    $range_ref = { add => { 10 => 20, 40 => 50, 80 => 100, 120 => 150, 200 => 300 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 51;
    $end       = 79;
    $test_name = "add + collapse range ($start - $end) adjacent to both previous and next ranges";
    $range_ref = { add => { 10 => 20, 40 => 100, 120 => 150, 200 => 250 }, messy => 0 };
    base_add_collapse_test( $start, $end, $range_ref, $test_name );

};

subtest 'remove various ranges' => sub {
    plan tests => 12;

    $start     = 0;
    $end       = 9;
    $test_name = "remove + collapse range ($start - $end) before 1st";
    $range_ref = { add => { 10 => 20, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, rm => {}, messy => 0 };
    base_rm_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 0;
    $end       = 10;
    $test_name = "remove + collapse range ($start - $end) that begins before 1st and ends on start of 1st";
    $range_ref = { add => { 11 => 20, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, rm => {}, messy => 0 };
    base_rm_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 0;
    $end       = 15;
    $test_name = "remove + collapse range ($start - $end) that begins before 1st and ends in middle of 1st";
    $range_ref = { add => { 16 => 20, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, rm => {}, messy => 0 };
    base_rm_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 0;
    $end       = 19;
    $test_name = "remove + collapse range ($start - $end) that begins before 1st and ends just before end of 1st";
    $range_ref = { add => { 20 => 20, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, rm => {}, messy => 0 };
    base_rm_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 0;
    $end       = 20;
    $test_name = "remove + collapse range ($start - $end) that begins before 1st and ends at end of 1st";
    $range_ref = { add => { 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, rm => {}, messy => 0 };
    base_rm_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 0;
    $end       = 45;
    $test_name = "remove + collapse range ($start - $end) that begins before 1st and ends in 2nd";
    $range_ref = { add => { 46 => 50, 80 => 100, 120 => 150, 200 => 250 }, rm => {}, messy => 0 };
    base_rm_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 50;
    $end       = 80;
    $test_name = "remove + collapse range ($start - $end) that begins at end of previous and ends at beginning of next";
    $range_ref = { add => { 10 => 20, 40 => 49, 81 => 100, 120 => 150, 200 => 250 }, rm => {}, messy => 0 };
    base_rm_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 51;
    $end       = 79;
    $test_name = "remove + collapse range ($start - $end) that begins just before end of previous and ends just before beginning of next";
    $range_ref = { add => { 10 => 20, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, rm => {}, messy => 0 };
    base_rm_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 130;
    $end       = 140;
    $test_name = "remove + collapse range ($start - $end) that begins and ends inside a range";
    $range_ref = { add => { 10 => 20, 40 => 50, 80 => 100, 120 => 129, 141 => 150, 200 => 250 }, rm => {}, messy => 0 };
    base_rm_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 75;
    $end       = 175;
    $test_name = "remove + collapse range ($start - $end) begins and ends outside of multiple ranges";
    $range_ref = { add => { 10 => 20, 40 => 50, 200 => 250 }, rm => {}, messy => 0 };
    base_rm_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 240;
    $end       = 260;
    $test_name = "remove + collapse range ($start - $end) that begins in last range and ends after";
    $range_ref = { add => { 10 => 20, 40 => 50, 80 => 100, 120 => 150, 200 => 239 }, rm => {}, messy => 0 };
    base_rm_collapse_test( $start, $end, $range_ref, $test_name );

    $start     = 251;
    $end       = 300;
    $test_name = "remove + collapse range ($start - $end) that begins just after last range";
    $range_ref = { add => { 10 => 20, 40 => 50, 80 => 100, 120 => 150, 200 => 250 }, rm => {}, messy => 0 };
    base_rm_collapse_test( $start, $end, $range_ref, $test_name );

};

sub base_add_collapse_test {
    my ( $start, $end, $range_ref, $test_name ) = @_;

    my $base_range_ref = build_base();
    add_range( $start, $end, $base_range_ref );
    collapse_and_test( $base_range_ref, $range_ref, $test_name );
}

sub base_rm_collapse_test {
    my ( $start, $end, $range_ref, $test_name ) = @_;

    my $base_range_ref = build_base();
    rm_range( $start, $end, $base_range_ref );
    collapse_and_test( $base_range_ref, $range_ref, $test_name );
}

sub build_base {
    my %base_range;

    add_range( 10,  20,  \%base_range );
    add_range( 40,  50,  \%base_range );
    add_range( 80,  100, \%base_range );
    add_range( 120, 150, \%base_range );
    add_range( 200, 250, \%base_range );

    collapse_ranges( \%base_range );

    return \%base_range;
}

sub collapse_and_test {
    my ( $base_range_ref, $range_ref, $test_name ) = @_;

    collapse_ranges($base_range_ref);

    is_deeply( $base_range_ref, $range_ref, $test_name );
    p $base_range_ref if $debug;
}
