package range;
{
    $range::VERSION = '0.1.0';
}

use strict;
use warnings;
use Exporter;
use List::Util 'max';
use List::MoreUtils 'lastidx';

our @ISA    = qw(Exporter);
our @EXPORT = qw(add_range collapse_ranges range_length is_in_range);

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

    return unless %$range_ref;

    my @cur_interval;
    my %temp_ranges;

    for my $start ( sort { $a <=> $b } keys %$range_ref ) {
        my $end = $range_ref->{$start};

        unless (@cur_interval) {
            @cur_interval = ( $start, $end );
            next;
        }

        my ( $cur_start, $cur_end ) = @cur_interval;
        if ( $start <= $cur_end + 1 ) {    # +1 makes it work for integer ranges only
            @cur_interval = ( $cur_start, max( $end, $cur_end ) );
        }
        else {
            $temp_ranges{ $cur_interval[0] } = $cur_interval[1];
            @cur_interval = ( $start, $end );
        }
    }
    $temp_ranges{ $cur_interval[0] } = $cur_interval[1];
    %$range_ref = %temp_ranges;
}

sub range_length {
    my $range_ref = shift;

    # Should only run if ranges added since last range_length?
    collapse_ranges($range_ref);

    my $length = 0;
    for ( keys %$range_ref ) {
        $length += $range_ref->{$_} - $_ + 1;    # +1 makes it work for integer ranges only
    }
    return $length;
}

sub is_in_range {
    my ( $query, $range_ref ) = @_;

    # Should only run if ranges added since last range_length?
    collapse_ranges($range_ref);

    my @starts = sort { $a <=> $b } keys %$range_ref;
    my $idx = lastidx { $_ <= $query } @starts;

    return 0 if $idx == -1;

    my $start = $starts[$idx];
    my $end   = $range_ref->{$start};
    if ( $end < $query ) {
        return 0;
    }
    else {
        return ( 1, $start, $end );
    }

}

1;