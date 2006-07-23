use warnings;
use strict;

package Jifty::Param;

=head1 NAME

Jifty::Param - Parameters for Jifty actions

=head1 DESCRIPTION

Describes a parameter to a C<Jifty::Action> object.  Do not construct
this by hand -- use L<Jifty::Param::Schema> in the action package to
declare parameters instead.

=head2 accessors

See L<Jifty::Web::Form::Field> for the list of possible keys that each
parameter can have.  In addition to the list there, you may use these
additional keys:

=over

=item constructor

A boolean which, if set, indicates that the argument B<must> be
present in the C<arguments> passed to create the action, rather than
being expected to be set later.

Defaults to false.

=item valid_values

An array reference.  Each element should be either:

=over 4

=item *

A hash reference with a C<display> field for the string to display for the
value, and a C<value> field for the value to actually send to the server.

=item *

A hash reference with a C<collection> field containing a L<Jifty::Collection>,
and C<display_from> and C<value_from> fields containing the names of methods to
call on each record in the collection to get C<display> and C<value>.

=item *

A simple string, which is treated as both C<display> and C<value>.

=back

=item available_values

Just like L<valid_values>, but represents the list of suggested values,
instead of the list of acceptable values.

=item sort_order

An integer of how the parameter sorts relative to other parameters.
This is usually implicitly generated by its declaration order.

=back

=cut


use base qw/Jifty::Web::Form::Field Class::Accessor::Fast/;
use constant ACCESSORS => qw(constructor valid_values available_values sort_order);

__PACKAGE__->mk_accessors(ACCESSORS);

sub accessors { (shift->SUPER::accessors(), ACCESSORS) }

=head2 new

Creates a new L<Jifty::Param> object.  Note that unlike L<Jifty::Web::Form::Field>,
the object is never magically reblessed into a subclass.  Should only be called
implicitly from a L<Jifty::Param::Schema> declaration.

=cut

# Inhibit the reblessing inherent in Jifty::Web::Form::Field->new
sub new {
    my $class = shift;
    $class->Class::Accessor::Fast::new({
        type          => 'text',
        class         => '',
        input_name    => '',
        default_value => '',
        sticky_value  => '',
        render_mode   => 'update',
        @_,
    });
}

1;