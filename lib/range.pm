package range;
{
    $range::VERSION = '0.1.1';
}

use strict;
use warnings;
use Exporter;
use List::Util 'max';
# use List::MoreUtils qw(lastidx lastval);
use List::MoreUtils 'lastidx';

our @ISA    = qw(Exporter);
# our @EXPORT = qw(add_range collapse_ranges range_length is_in_range);
our @EXPORT = qw(add_range collapse_ranges range_length is_in_range rm_range);

sub add_range {
    my ( $start, $end, $range_ref ) = @_;
    if ( exists $range_ref->{$start} ) {
        $range_ref->{$start} = max( $end, $range_ref->{$start} );
    }
    else {
        $range_ref->{$start} = $end;
    }
}

sub rm_range {    # should add to sub-hash otherwise collapse_ranges would need to be called first...
    my ( $start, $end, $range_ref ) = @_;
    my @starts = sort { $a <=> $b } keys %$range_ref;

    my $left_start_idx  = lastidx { $_ < $start } @starts;
    my $right_start_idx = lastidx { $_ <= $end } @starts;

    my $left_start  = $starts[$left_start_idx];
    my $right_start = $starts[$right_start_idx];

    my $left_end  = $range_ref->{$left_start};
    my $right_end = $range_ref->{$right_start};

    if ( $right_start_idx - $left_start_idx > 0 ) {
        delete @{$range_ref}
          { @starts[ $left_start_idx + 1 .. $right_start_idx ] };
    }
    if ( $start < $left_end && $left_start_idx != -1 ) {
        $range_ref->{$left_start} = $start - 1;
    }
    if ( $end >= $right_start && $end < $right_end ) {
        $range_ref->{ $end + 1 } = $right_end;
    }
}

sub collapse_ranges {    # collapse added ranges, then collapse to-be-removed ranges, then remove to-be-removed ranges from collapsed added ranges
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