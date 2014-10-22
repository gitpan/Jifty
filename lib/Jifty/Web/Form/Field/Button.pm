use warnings;
use strict;
 
package Jifty::Web::Form::Field::Button;

use base qw/Jifty::Web::Form::Field/;
__PACKAGE__->mk_accessors(qw/button_as_link/);

=head2 accessors

Provide the C<button_as_link> accessor (in addition to
L<Jifty::Web::Form::Field>'s default accessors), which controls if the
button is reworked in javascript to appear as a link.

=cut

sub accessors { shift->SUPER::accessors(), 'button_as_link' }

=head2 render_widget

Renders the button widget.

=cut

sub render_widget {
    my $self  = shift;
    my $field = join(
        ' ',
        '<input',
        'type="submit"',
        'name="' . $self->input_name . '" ',
        'value="' . _($self->label ). '"',
        'id="'. Jifty->web->serial . '"',
        $self->_widget_class('button', ($self->button_as_link ? ("button_as_link") : ())),
        $self->javascript,
        ' />',
        "\n"
    );
    Jifty->web->out($field);
    return '';
}

1;
