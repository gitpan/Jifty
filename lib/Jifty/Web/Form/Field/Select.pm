use warnings;
use strict;
 
package Jifty::Web::Form::Field::Select;

use base qw/Jifty::Web::Form::Field/;

=head1 NAME

Jifty::Web::Form::Field::Select - Add a list/popup menu control to your forms

=head1 METHODS

=head2 render_widget

Renders the select widget.

=cut

sub render_widget {
    my $self  = shift;
    my $field = qq! <select !;
    $field .= qq! name="@{[ $self->input_name ]}"!;
    $field .= qq! id="@{[ $self->element_id ]}"!;
    $field .= qq! title="@{[ $self->title ]}"! if ($self->title);
    $field .= $self->_widget_class;
    $field .= $self->javascript;
    $field .= q! multiple="multiple"! if $self->multiple;
    $field .= qq!      >\n!;
    my $current_value = $self->current_value;
    for my $opt (@{ $self->action->available_values($self->name) }) {
        my $display = $opt->{'display'};
        my $value   = $opt->{'value'};
        $value = "" unless defined $value;
        $field .= qq!<option value="@{[ Jifty->web->escape($value) ]}"!;
        $field .= qq! selected="selected"!
          if defined $current_value
              && (
                  ref $current_value eq 'ARRAY'
                  ? ( grep { $value eq $_ } @$current_value )
                  : $current_value eq $value );
        $field .= qq!>!;
        $field .= Jifty->web->escape(_($display)) if defined $display;
        $field .= qq!</option>\n!;
    } 
    $field .= qq!</select>\n!;
    Jifty->web->out($field);
    '';
}


=head2 render_value

Rather than rendering the "key" side of our value for this field, render
what would actually display to the user in the select-box

=cut


sub render_value {
    my $self  = shift;
    my $field = '<span';
    $field .= qq! class="@{[ $self->classes ]}"> !;
    my $value = $self->current_value;
    if(defined $value) {
        my @value = grep { $_->{value} eq $value }
                        @{ $self->action->available_values($self->name) };
        $value = $value[0]->{display} if scalar @value;
    }
    $field .= Jifty->web->escape(_($value)) if defined $value;
    $field .= qq!</span>\n!;
    Jifty->web->out($field);
    return '';
}

1;
