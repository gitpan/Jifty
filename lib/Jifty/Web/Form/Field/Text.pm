use warnings;
use strict;

package Jifty::Web::Form::Field::Text;
use base qw/Jifty::Web::Form::Field/;

=head1 NAME

Jifty::Web::Form::Field::Text - Renders as a small text field

=cut

our $VERSION = 1;

=head2 classes

Output text fields with the class 'text'

=cut

sub classes {
    my $self = shift;
    return join(' ', 'text', ($self->SUPER::classes));
}

1;
