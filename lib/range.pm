package range;
{
    $range::VERSION = '0.3.0';
}

use strict;
use warnings;
use List::Util 'max';
use List::MoreUtils qw(lastidx lastval);
use Scalar::Util 'looks_like_number';
use Carp;

our ( @ISA, @EXPORT_OK, %EXPORT_TAGS );

BEGIN {
    require Exporter;
    @ISA = qw(Exporter);
    @EXPORT_OK =
      qw(add_range collapse_ranges range_length is_in_range rm_range output_ranges output_integers);
    %EXPORT_TAGS = ( ALL => [@EXPORT_OK] );
}

sub add_range {
    _update_range( @_, 'add' );
}

sub rm_range {
    _update_range( @_, 'rm' );
}

sub _update_range {
    my ( $start, $end, $range_ref, $add_or_rm ) = @_;

    croak "'$start' not a number in range '$start to $end'"
      unless looks_like_number $start;
    croak "'$end' not a number in range '$start to $end'"
      unless looks_like_number $end;

    if ( $start > $end ) {
        carp "Warning: Range start ($start) is greater than range end ($end); values have been swapped";
        ( $start, $end ) = ( $end, $start );
    }

    if ( exists $range_ref->{$add_or_rm}{$start} ) {
        $range_ref->{$add_or_rm}{$start} = max( $end, $range_ref->{$add_or_rm}{$start} );
    }
    else {
        $range_ref->{$add_or_rm}{$start} = $end;
    }
    $range_ref->{messy} = 1;
}

sub collapse_ranges {
    my $range_ref = shift;

    return if $range_ref->{messy} == 0;

    _collapse( $range_ref->{add} ) if $range_ref->{add};

    if ( $range_ref->{rm} ) {
        _collapse( $range_ref->{rm} );
        _remove($range_ref);
    }

    $range_ref->{messy} = 0;
}

sub _collapse {
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

sub _remove {
    my $range_ref = shift;

    my @starts = sort { $a <=> $b } keys %{$range_ref->{add}};

    for my $start ( sort { $a <=> $b } keys %{ $range_ref->{rm} } ) {
        my $end = $range_ref->{rm}{$start};

        my $left_start_idx  = lastidx { $_ < $start } @starts;
        my $right_start_idx = lastidx { $_ <= $end } @starts;

        my $left_start  = $starts[$left_start_idx];
        my $right_start = $starts[$right_start_idx];

        my $left_end  = $range_ref->{add}{$left_start};
        my $right_end = $range_ref->{add}{$right_start};

        # range to remove touches the start of at least one added range
        if ( $right_start_idx - $left_start_idx > 0 ) {
            delete @{ $range_ref->{add} }
              { @starts[ $left_start_idx + 1 .. $right_start_idx ] };
            splice @starts, 0, $right_start_idx + 1 if $right_start_idx > -1;
        }
        else {
            splice @starts, 0, $left_start_idx + 1 if $left_start_idx > -1;
        }

        # range to remove starts inside an added range
        if ( $start <= $left_end && $left_start_idx != -1 ) {
            $range_ref->{add}{$left_start} = $start - 1;
        }

        # range to remove ends inside an added range
        if ( $end >= $right_start && $end < $right_end ) {
            my $new_start = $end + 1;
            $range_ref->{add}{$new_start} = $right_end;
            unshift @starts, $new_start;
        }

        delete ${ $range_ref->{rm} }{$start};
    }
}

sub range_length {
    my $range_ref = shift;

    collapse_ranges($range_ref);

    my $length = 0;
    for ( keys %{ $range_ref->{add} } ) {
        $length += $range_ref->{add}{$_} - $_ + 1;    # +1 makes it work for integer ranges only
    }
    return $length;
}

sub is_in_range {
    my ( $query, $range_ref ) = @_;

    collapse_ranges($range_ref);

    my @starts = sort { $a <=> $b } keys %{ $range_ref->{add} };
    my $start = lastval { $_ <= $query } @starts;

    return 0 unless defined $start;

    my $end   = $range_ref->{add}{$start};
    if ( $end < $query ) {
        return 0;
    }
    else {
        return ( 1, $start, $end );
    }

}

sub output_ranges {
    my $range_ref = shift;

    collapse_ranges($range_ref);

    if ( wantarray() ) {
        return %{ $range_ref->{add} };
    }
    elsif ( defined wantarray() ) {
        return join ',', map { "$_..$range_ref->{add}{$_}" }
          sort { $a <=> $b } keys %{ $range_ref->{add} };
    }
    elsif ( !defined wantarray() ) {
        carp 'Useless use of output_ranges() in void context';
    }
    else { croak 'Bad context for output_ranges()'; }
}

sub output_integers {
    my $range_ref = shift;

    my @ranges = split ",", output_ranges($range_ref);
    my @elements;

    for (@ranges) {
        for my $value ( eval $_ ) {
            push @elements, $value;
        }
    }

    if ( wantarray() ) {
        return @elements;
    }
    elsif ( defined wantarray() ) {
        return join ',', @elements;
    }
    elsif ( !defined wantarray() ) {
        carp 'Useless use of output_elements() in void context';
    }
    else { croak 'Bad context for output_elements()'; }
}

1;
