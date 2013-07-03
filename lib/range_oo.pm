package range_oo;
{
    $range_oo::VERSION = '0.3.0';
}

use strict;
use warnings;
use List::Util 'max';
use List::MoreUtils qw(lastidx lastval);
use Scalar::Util 'looks_like_number';
use Carp;
use Mouse;

# our ( @ISA, @EXPORT_OK, %EXPORT_TAGS );

# BEGIN {
#     require Exporter;
#     @ISA = qw(Exporter);
#     @EXPORT_OK =
#       qw(add_range collapse_ranges range_length is_in_range rm_range output_ranges output_integers);
#     %EXPORT_TAGS = ( ALL => [@EXPORT_OK] );
# }

has 'add'   => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'rm'    => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'messy' => ( is => 'rw', isa => 'Bool',    default => 1 );
has 'start' => ( is => 'rw', isa => 'Num' );
has 'end'   => ( is => 'rw', isa => 'Num' );

sub add_range_oo {
    my $self = shift;

    my @ranges = @_;
    croak "Odd number of elements in input ranges (start/stop pairs expected)"
      if scalar @ranges % 2 != 0;
    while (scalar @ranges) {
        my ( $start, $end ) = splice @ranges, 0, 2;
        $self->_update_range_oo( $start, $end, 'add');
    }
}

sub rm_range_oo {
    my $self = shift;

    my @ranges = @_;
    croak "Odd number of elements in input ranges (start/stop pairs expected)"
      if scalar @ranges % 2 != 0;
    while (scalar @ranges) {
        my ( $start, $end ) = splice @ranges, 0, 2;
        $self->_update_range_oo( $start, $end, 'rm');
    }
}

sub _update_range_oo {
    my $self = shift;

    my ( $start, $end, $add_or_rm ) = @_;

    croak "'$start' not a number in range '$start to $end'"
      unless looks_like_number $start;
    croak "'$end' not a number in range '$start to $end'"
      unless looks_like_number $end;

    if ( $start > $end ) {
        carp "Warning: Range start ($start) is greater than range end ($end); values have been swapped";
        ( $start, $end ) = ( $end, $start );
    }

    if ( exists $self->{$add_or_rm}{$start} ) {
        $self->{$add_or_rm}{$start} = max( $end, $self->{$add_or_rm}{$start} );
    }
    else {
        $self->{$add_or_rm}{$start} = $end;
    }

    $self->messy(1);
}

sub collapse_ranges_oo {
    my $self = shift;

    return if $self->messy == 0;

    $self->_collapse_oo('add') if scalar keys %{ $self->{add} };

    if ( scalar keys %{ $self->{rm} } ) {
        $self->_collapse_oo('rm');
        $self->_remove_oo;
    }

    $self->messy(0);
}

sub _collapse_oo {
    my $self = shift;

    my $add_or_rm = shift;

    my @cur_interval;
    my %temp_ranges;

    for my $start ( sort { $a <=> $b } keys $self->{$add_or_rm} ) {
        my $end = $self->{$add_or_rm}{$start};

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
    $self->{$add_or_rm} = \%temp_ranges;
}


sub _remove_oo {
    my $self = shift;

    my @starts = sort { $a <=> $b } keys $self->add;

    for my $start ( sort { $a <=> $b } keys $self->rm ) {
        my $end = $self->{rm}{$start};

        my $left_start_idx  = lastidx { $_ < $start } @starts;
        my $right_start_idx = lastidx { $_ <= $end } @starts;

        my $left_start  = $starts[$left_start_idx];
        my $right_start = $starts[$right_start_idx];

        my $left_end  = $self->{add}{$left_start};
        my $right_end = $self->{add}{$right_start};

        # range to remove touches the start of at least one added range
        if ( $right_start_idx - $left_start_idx > 0 ) {
            delete @{ $self->{add} }
              { @starts[ $left_start_idx + 1 .. $right_start_idx ] };
            splice @starts, 0, $right_start_idx + 1 if $right_start_idx > -1;
        }
        else {
            splice @starts, 0, $left_start_idx + 1 if $left_start_idx > -1;
        }

        # range to remove starts inside an added range
        # if ( defined $left_end && $start <= $left_end && $left_start_idx != -1 ) {
        if ( $start <= $left_end && $left_start_idx != -1 ) {
            $self->{add}{$left_start} = $start - 1;
        }

        # range to remove ends inside an added range
        # if ( defined $right_end && $end >= $right_start && $end < $right_end ) {
        if ( $end >= $right_start && $end < $right_end ) {
            my $new_start = $end + 1;
            $self->{add}{ $new_start } = $right_end;
            unshift @starts, $new_start;
        }

        delete ${ $self->{rm} }{$start};
    }
}

sub range_length_oo {
    my $self = shift;

    $self->collapse_ranges_oo;

    my $length = 0;
    for ( keys $self->add ) {
        $length += $self->{add}{$_} - $_ + 1;    # +1 makes it work for integer ranges only
    }
    return $length;
}

sub is_in_range_oo {
    my $self = shift;

    my $query = shift;

    $self->collapse_ranges_oo;

    my @starts = sort { $a <=> $b } keys $self->add;
    my $start = lastval { $_ <= $query } @starts;

    return 0 unless defined $start;

    my $end   = $self->{add}{$start};
    if ( $end < $query ) {
        return 0;
    }
    else {
        return ( 1, $start, $end );
    }

}

sub output_ranges_oo {
    my $self = shift;

    $self->collapse_ranges_oo;

    if ( wantarray() ) {
        return %{ $self->add };
    }
    elsif ( defined wantarray() ) {
        return join ',', map { "$_..$self->{add}{$_}" }
          sort { $a <=> $b } keys $self->add;
    }
    elsif ( !defined wantarray() ) {
        carp 'Useless use of output_ranges() in void context';
    }
    else { croak 'Bad context for output_ranges()'; }
}

sub output_integers_oo {
    my $self = shift;

    my @ranges = split ",", $self->output_ranges_oo;
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

__PACKAGE__->meta->make_immutable();
