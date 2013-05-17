#!/usr/bin/env perl
# FILE_NAME.pl
# Mike Covington
# created: 2013-05-16
#
# Description:
#
use strict;
use warnings;
use autodie;
use feature 'say';
use Data::Printer;
use List::Util qw(first max);

my %range;

$range{10} = 1000000;
$range{10} = 30;
$range{20} = 60;
$range{50} = 80;
$range{100} = 800;
$range{100} = 840;
$range{100} = 850;
$range{200} = 400;
$range{1000} = 8000;
$range{5000} = 9000;

sub add_range {
    my ( $start, $end, $range_ref ) = @_;
    if ( exists $range_ref->{$start} ) {
        $range_ref->{$start} = max($end, $range_ref->{$start});
    }
    else {
        $range_ref->{$start} = $end;
    }
}

sub add_range_no_ref {
    my ( $start, $end ) = @_;
    if ( exists $range{$start} ) {
        $range{$start} = max($end, $range{$start});
    }
    else {
        $range{$start} = $end;
    }
}

my $iterations = 1_000_000;

for (1..$iterations) {
    add_range( $_ , $_ + 5 , \%range );
}

# for (1..$iterations) {
#     add_range_no_ref( $_ , $_ + 5 );
# }

# add_range( 100006, 100009 );

my @cur_interval;
my @result;
my %final_ranges_1;

for my $start ( sort { $a <=> $b } keys %range ) {
    # say $start;
    unless (@cur_interval) {
        # say "sdfsdfsdf $start";
        @cur_interval = ( $start, $range{$start});
        next;
    }
    # say "@cur_interval";
    my ( $cstart, $cend ) = @cur_interval;
    if ( $start <= $cend + 1) {
        @cur_interval = ( $cstart , max($range{$start}, $cend ));
    }
    else {
        push @result, @cur_interval;
        $final_ranges_1{$cur_interval[0]} = $cur_interval[1];
        @cur_interval = ( $start, $range{$start});
    }
}
push @result, @cur_interval;
$final_ranges_1{$cur_interval[0]} = $cur_interval[1];

my %final_ranges = @result;

p %final_ranges;
p %final_ranges_1;

# p @cur_interval;

p @result;

# ranges = [
#   (11, 15),
#   (3, 9),
#   (12, 14),
#   (13, 20),
#   (1, 5)]

# result = []
# cur = None
# for start, stop in sorted(ranges): # sorts by start
#   if cur is None:
#     cur = (start, stop)
#     continue
#   cStart, cStop = cur
#   if start <= cStop:
#     cur = (cStart, max(stop, cStop))
#   else:
#     result.append(cur)
#     cur = (start, stop)
# result.append(cur)

# print result





