package Number::RangeTracker;
use strict;
use warnings;
use List::Util 'max';
use List::MoreUtils qw(lastidx lastval);
use Scalar::Util 'looks_like_number';
use Carp;
use Mouse;

=head1 NAME

Number::RangeTracker - Track lots of numerical ranges quickly and easily

=head1 VERSION

Version 0.5.0

=cut

our $VERSION = '0.5.0';

=head1 SYNOPSIS

X

=head1 DESCRIPTION

X

=over 4

=item new

Initializes a new Number::RangeTracker object.

=cut

has 'ranges' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'remove' => ( is => 'rw', isa => 'HashRef', default => sub { {} } );
has 'messy_add' => ( is => 'rw', isa => 'Bool', default => 0 );
has 'messy_rem' => ( is => 'rw', isa => 'Bool', default => 0 );
has 'units'     => ( is => 'ro', isa => 'Num',  default => 1 );
has 'start'     => ( is => 'rw', isa => 'Num' );
has 'end'       => ( is => 'rw', isa => 'Num' );

=item add_range

X

=cut

sub add_range {
    my $self = shift;

    my $ranges = _get_range_inputs(@_);
    while (scalar @$ranges) {
        my ( $start, $end ) = splice @$ranges, 0, 2;
        $self->_update_range( $start, $end, 'ranges');
    }
}

sub _get_range_inputs {
    my @range_input = @_;

    my @ranges;
    for (@range_input) {
        if ( ref $_ eq "ARRAY" ) {    # [ 1, 10 ], [ 16, 20 ]
            push @ranges, @$_;
        }
        elsif (/^\d+\.\.\d+$/) {      # '1..10', '16..20'
            push @ranges, split /\.\./;
        }
        else {                        # 1, 10, 16, 20
            push @ranges, $_;
        }
    }

    croak "Odd number of elements in input ranges (start/stop pairs expected)"
      if scalar @ranges % 2 != 0;

    return \@ranges;
}

=item remove_range

X

=cut

sub remove_range {
    my $self = shift;

    my $ranges = _get_range_inputs(@_);
    while (scalar @$ranges) {
        my ( $start, $end ) = splice @$ranges, 0, 2;
        $self->_update_range( $start, $end, 'remove');
    }
}

sub _update_range {
    my $self = shift;

    my ( $start, $end, $ranges_or_remove ) = @_;

    $self->collapse_ranges
        if $self->messy_rem && $ranges_or_remove eq 'ranges';

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

    if ( $ranges_or_remove eq 'ranges' ) {
        $self->messy_add(1);
    }
    else {
        $self->messy_rem(1);
    }
}

=item collapse_ranges

X

=cut

sub collapse_ranges {
    my $self = shift;

    return unless $self->messy_add || $self->messy_rem;

    $self->_collapse('ranges') if $self->messy_add;

    if ( $self->messy_rem ) {
        $self->_collapse('remove');
        $self->_remove;
    }

    $self->messy_add(0);
    $self->messy_rem(0);
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
        next unless defined $left_start && defined $right_start;

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

=item range_length

X

=cut

sub range_length {
    my $self = shift;

    $self->collapse_ranges;

    my $length = 0;
    for ( keys %{ $self->ranges } ) {
        $length += $self->{ranges}{$_} - $_ + 1;    # +1 makes it work for integer ranges only
    }
    return $length;
}

=item is_in_range

X

=cut

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

=item output_ranges

X

=cut

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

=item output_integers

X

=cut

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

=item complement

X

=cut

sub complement {
    my ( $self, $universe_start, $universe_end ) = @_;

    $universe_start = '-inf' unless defined $universe_start;
    $universe_end   = '+inf' unless defined $universe_end;

    my $complement = Number::RangeTracker->new;
    $complement->add_range( $universe_start, $universe_end );
    $complement->remove_range( $self->output_ranges );

    return $complement->output_ranges;
}

=back

=head1 SEE ALSO

L<Number::Range|Number::Range>,
L<Range::Object::Serial|Range::Object::Serial>,
L<Tie::RangeHash|Tie::RangeHash>,
L<Array::IntSpan|Array::IntSpan>,
L<Bio::Range|Bio::Range>,
L<Number::Tolerant|Number::Tolerant>

=head1 SOURCE AVAILABILITY

The source code is on Github:
L<https://github.com/mfcovington/Number-RangeTracker>

=head1 AUTHOR

Michael F. Covington, <mfcovington@gmail.com>

=head1 BUGS

Please report any bugs or feature requests at
L<https://github.com/mfcovington/Number-RangeTracker/issues>.

=head1 INSTALLATION

To install this module from GitHub using cpanm:

    cpanm git@github.com:mfcovington/Number-RangeTracker.git

Alternatively, download and run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

=head1 SUPPORT AND DOCUMENTATION

You can find documentation for this module with the perldoc command.

    perldoc Number::RangeTracker

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Michael F. Covington.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut

__PACKAGE__->meta->make_immutable();
