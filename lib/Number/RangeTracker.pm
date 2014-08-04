package RangeTracker;
{
    $Number::RangeTracker::VERSION = '0.4.0';
}

use strict;
use warnings;
use List::Util 'max';
use List::MoreUtils qw(lastidx lastval);
use Scalar::Util 'looks_like_number';
use Carp;
use Mouse;

has 'ranges' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'remove' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'messy'  => ( is => 'rw', isa => 'Bool',    default => 1 );
has 'units'  => ( is => 'ro', isa => 'Num',     default => 1 );
has 'start'  => ( is => 'rw', isa => 'Num' );
has 'end'    => ( is => 'rw', isa => 'Num' );

sub add_range {
    my $self = shift;

    my @ranges = @_;
    croak "Odd number of elements in input ranges (start/stop pairs expected)"
      if scalar @ranges % 2 != 0;
    while (scalar @ranges) {
        my ( $start, $end ) = splice @ranges, 0, 2;
        $self->_update_range( $start, $end, 'ranges');
    }
}

sub remove_range {
    my $self = shift;

    my @ranges = @_;
    croak "Odd number of elements in input ranges (start/stop pairs expected)"
      if scalar @ranges % 2 != 0;
    while (scalar @ranges) {
        my ( $start, $end ) = splice @ranges, 0, 2;
        $self->_update_range( $start, $end, 'remove');
    }
}

sub _update_range {
    my $self = shift;

    my ( $start, $end, $ranges_or_remove ) = @_;

    croak "'$start' not a number in range '$start to $end'"
      unless looks_like_number $start;
    croak "'$end' not a number in range '$start to $end'"
      unless looks_like_number $end;

    if ( $start > $end ) {
        carp "Warning: Range start ($start) is greater than range end ($end); values have been swapped";
        ( $start, $end ) = ( $end, $start );
    }

    if ( exists $self->{$ranges_or_remove}{$start} ) {
        $self->{$ranges_or_remove}{$start} = max( $end, $self->{$ranges_or_remove}{$start} );
    }
    else {
        $self->{$ranges_or_remove}{$start} = $end;
    }

    $self->messy(1);
}

sub collapse_ranges {
    my $self = shift;

    return if $self->messy == 0;

    $self->_collapse('ranges') if scalar keys %{ $self->{ranges} };

    if ( scalar keys %{ $self->{remove} } ) {
        $self->_collapse('remove');
        $self->_remove;
    }

    $self->messy(0);
}

sub _collapse {
    my $self = shift;

    my $ranges_or_remove = shift;

    my @cur_interval;
    my %temp_ranges;

    for my $start ( sort { $a <=> $b } keys %{ $self->{$ranges_or_remove} } ) {
        my $end = $self->{$ranges_or_remove}{$start};

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
    $self->{$ranges_or_remove} = \%temp_ranges;
}


sub _remove {
    my $self = shift;

    my @starts = sort { $a <=> $b } keys %{ $self->ranges };

    for my $start ( sort { $a <=> $b } keys %{ $self->remove } ) {
        my $end = $self->{remove}{$start};

        my $left_start_idx  = lastidx { $_ < $start } @starts;
        my $right_start_idx = lastidx { $_ <= $end } @starts;

        my $left_start  = $starts[$left_start_idx];
        my $right_start = $starts[$right_start_idx];

        my $left_end  = $self->{ranges}{$left_start};
        my $right_end = $self->{ranges}{$right_start};

        # range to remove touches the start of at least one rangesed range
        if ( $right_start_idx - $left_start_idx > 0 ) {
            delete @{ $self->{ranges} }
              { @starts[ $left_start_idx + 1 .. $right_start_idx ] };
            splice @starts, 0, $right_start_idx + 1 if $right_start_idx > -1;
        }
        else {
            splice @starts, 0, $left_start_idx + 1 if $left_start_idx > -1;
        }

        # range to remove starts inside an rangesed range
        # if ( defined $left_end && $start <= $left_end && $left_start_idx != -1 ) {
        if ( $start <= $left_end && $left_start_idx != -1 ) {
            $self->{ranges}{$left_start} = $start - 1;
        }

        # range to remove ends inside an rangesed range
        # if ( defined $right_end && $end >= $right_start && $end < $right_end ) {
        if ( $end >= $right_start && $end < $right_end ) {
            my $new_start = $end + 1;
            $self->{ranges}{ $new_start } = $right_end;
            unshift @starts, $new_start;
        }

        delete ${ $self->{remove} }{$start};
    }
}

sub range_length {
    my $self = shift;

    $self->collapse_ranges;

    my $length = 0;
    for ( keys %{ $self->ranges } ) {
        $length += $self->{ranges}{$_} - $_ + 1;    # +1 makes it work for integer ranges only
    }
    return $length;
}

sub is_in_range {
    my $self = shift;

    my $query = shift;

    $self->collapse_ranges;

    my @starts = sort { $a <=> $b } keys %{ $self->ranges };
    my $start = lastval { $_ <= $query } @starts;

    return 0 unless defined $start;

    my $end   = $self->{ranges}{$start};
    if ( $end < $query ) {
        return 0;
    }
    else {
        return ( 1, $start, $end );
    }

}

sub output_ranges {
    my $self = shift;

    $self->collapse_ranges;

    if ( wantarray() ) {
        return %{ $self->ranges };
    }
    elsif ( defined wantarray() ) {
        return join ',', map { "$_..$self->{ranges}{$_}" }
          sort { $a <=> $b } keys %{ $self->ranges };
    }
    elsif ( !defined wantarray() ) {
        carp 'Useless use of output_ranges() in void context';
    }
    else { croak 'Bad context for output_ranges()'; }
}

sub output_integers {
    my $self = shift;

    my @ranges = split ",", $self->output_ranges;
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

sub inverse {
    my $self = shift;

    my %ranges = $self->output_ranges;
    my $end;
    my $first = 1;
    my %temp_ranges;
    for my $start ( sort { $a <=> $b } keys %ranges ) {
        $temp_ranges{$end + 1} = $start - 1 unless $first;
        $end = $ranges{$start};
        $first = 0;
    }

    return %temp_ranges;
}

__PACKAGE__->meta->make_immutable();
