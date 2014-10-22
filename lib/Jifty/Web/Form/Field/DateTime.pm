use warnings;
use strict;
 
package Jifty::Web::Form::Field::DateTime;

use base qw/Jifty::Web::Form::Field/;

=head1 NAME

Jifty::Web::Form::Field::DateTime - Add date pickers to your forms

=head1 METHODS

=head2 classes

Output date fields with the class 'date'

=cut

sub classes {
    my $self = shift;
    return join(' ', 'datetime', ($self->SUPER::classes));
}

=head2 canonicalize_value

If the value is a DateTime, return nothing if the epoch is 0

=cut

sub canonicalize_value {
    my $self  = shift;
    my $value = $self->current_value;

    if (UNIVERSAL::isa($value, 'DateTime')) {
        return unless $value->epoch;
    }

    return $value;
}

1;
