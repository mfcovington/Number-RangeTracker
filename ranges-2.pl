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
use List::Util qw(max);

my %range;

my $iterations = 5_000_000;

for ( 1 .. $iterations ) {
    add_range( $_, $_ + 5, \%range );

    # collapse_ranges(\%range) if $_ % 10000 == 0;
    # collapse_ranges(\%range) if scalar keys %range > 1000;
    # collapse_ranges(\%range);
}

collapse_ranges( \%range );

say range_length( \%range );

p %range;

sub add_range {
    my ( $start, $end, $range_ref ) = @_;
    if ( exists $range_ref->{$start} ) {
        $range_ref->{$start} = max( $end, $range_ref->{$start} );
    }
    else {
        $range_ref->{$start} = $end;
    }
}

sub collapse_ranges {
    my $range_ref = shift;

    my @cur_interval;
    my @result;
    my %temp_ranges;

    for my $start ( sort { $a <=> $b } keys %$range_ref ) {
        unless (@cur_interval) {
            @cur_interval = ( $start, $range_ref->{$start} );
            next;
        }
        my ( $cstart, $cend ) = @cur_interval;
        if ( $start <= $cend + 1 ) {
            @cur_interval = ( $cstart, max( $range_ref->{$start}, $cend ) );
        }
        else {
            push @result, @cur_interval;
            $temp_ranges{ $cur_interval[0] } = $cur_interval[1];
            @cur_interval = ( $start, $range_ref->{$start} );
        }
    }
    push @result, @cur_interval;
    $temp_ranges{ $cur_interval[0] } = $cur_interval[1];
    %$range_ref = %temp_ranges;
}

sub range_length {
    my $range_ref = shift;
    my $length;
    for ( keys %$range_ref ) {
        $length += $range_ref->{$_} - $_ + 1;
    }
    return $length;
}

