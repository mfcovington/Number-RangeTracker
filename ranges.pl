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
use List::Util qw(first);

my %range;

$range{10} = 30;
$range{50} = 80;

my $iteration = 100_000;

for (1..$iteration) {
    add_range( 20, 60);
}

p %range;

my @numbers;

# for (1..10_000_000) {
#     push @numbers, $_;
# }

sub add_range {
    my ( $start, $end ) = @_;

    if ( exists $range{ $start } ) {
        # say "start exists";
    }
    else {
        my @all_starts = sort { $a <=> $b } ( keys %range, $start, $end );
        # p @all_starts;
        my $idx_start = first { $all_starts[$_] == $start } 0..$#all_starts;
        my $idx_end = first { $all_starts[$_] == $end } 0..$#all_starts;
        # say "$idx_start: $all_starts[$idx_start]";
        # say "$idx_end: $all_starts[$idx_end]";
        my $old_start = $all_starts[ $idx_start - 1 ];
        if ( $idx_start == 0 ) {
            $range{$start} = $end;
        }
        elsif ( $range{ $old_start } < $end ) {
            my $idx_dif = $idx_end - $idx_start;
            if ( $idx_dif == 1 ) {
                $range{ $old_start } = $end;
            }
            else {
                my $old_restart = $all_starts[ $idx_end - 1 ];
                my $old_reend = $range{$old_restart};
                $range{$old_start} = $old_reend;
                # delete keys for ( 2..$idx_dif )
            }
        }
    }

}



$range{10} = 30;
$range{20} = 60;
$range{50} = 80;

p %range;

collapse_ranges();

p %range;

sub collapse_ranges {
    my @all_starts = sort { $a <=> $b } keys %range;
    p @all_starts;
    for my $start (@all_starts) {
        # next if
        next if $range{$start} > $all_starts[$#all_starts];
        my $idx = first { $all_starts[$_] > $range{$start} } 0..$#all_starts;
        $range{$start} = $range{$all_starts[ $idx - 1 ]};
        say "$all_starts[ $idx - 1 ] ... $range{$all_starts[ $idx - 1 ]}";
        delete $range{$all_starts[ $idx - 1 ]};
        say "$start - $range{$start} - $idx - $all_starts[$idx] - $all_starts[$#all_starts]";
    }
}

