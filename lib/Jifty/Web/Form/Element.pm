use warnings;
use strict;

package Jifty::Web::Form::Element;

=head1 NAME

Jifty::Web::Form::Element - Some item that can be rendered in a form

=head1 DESCRIPTION

Describes any HTML element that might live in a form, and thus might
have javascript on it.

Handlers are placed on L<Jifty::Web::Form::Element> objects by calling
the name of the javascript event handler, such as C<onclick>, with a
set of arguments.

The format of the arguments passed to C<onclick> (or any similar method)
is a hash reference, with the following possible keys:

=over

=item submit (optional)

An action (or moniker of an action) to be submitted when the event is fired.

=item region (optional)

The region that should be updated.  This defaults to the current
region.

=item args (optional)

Arguments to the region.  These will override the default arguments to
the region.

=item fragment (optional)

The fragment that should go into the region.  The default is whatever
fragment the region was originally rendered with.

=back

=cut

use base qw/Jifty::Object Class::Accessor/;
use Jifty::JSON;

=head2 handlers

Currently, the only supported event handlers are C<onclick>.

=cut

sub handlers { qw(onclick); }

=head2 accessors

Any descendant of L<Jifty::Web::Form::Element> should be able to
accept any of the event handlers (above) as one of the keys to its
C<new> parameter hash.

=cut

sub accessors { shift->handlers, qw(class key_binding id label tooltip) }
__PACKAGE__->mk_accessors(qw(onclick class key_binding id label tooltip));

=head2 javascript

Returns the javsscript necessary to make the events happen.

=cut

sub javascript {
    my $self = shift;

    my $response = "";
    for my $trigger ( $self->handlers ) {
        my $value = $self->$trigger;
        next unless $value;

        my @fragments;
        my @actions;

        for my $hook (ref $value eq "ARRAY" ? @{$value} : ($value)) {
            my %args;

            # Submit action
            if ( $hook->{submit} ) {
                $hook->{submit} = [ $hook->{submit} ] unless ref $hook->{submit} eq "ARRAY";
                push @actions, map { ref $_ ? $_->moniker : $_ } @{ $hook->{submit} };
            }

            # Placement
            if (exists $hook->{replace_with}) {
                @args{qw/mode path/} = ('Replace', $hook->{replace_with});
            } elsif (exists $hook->{append}) {
                @args{qw/mode path/} = ('Bottom', $hook->{append});
            } elsif (exists $hook->{prepend}) {
                @args{qw/mode path/} = ('Top', $hook->{prepend});
            } elsif ((exists $hook->{refresh_self} and Jifty->web->current_region) or $hook->{args}) {
                # If we just pass arguments, treat as a refresh_self
                 @args{qw/mode path/} = ('Replace', Jifty->web->current_region->path);
            } else {
                # If we're not doing any of the above, skip this one
                next;
            }

            # What element we're replacing.
            if ($hook->{element}) {
                $args{element} = $hook->{element};
                $args{region}  = $args{element} =~ /^#region-(\S+)/ ? "$1-".Jifty->web->serial : Jifty->web->serial;
            } else {
                $args{region}  = $hook->{region} || Jifty->web->qualified_region;
            }

            # Arguments
            $args{args} = {Jifty::Request::Mapper->query_parameters( %{ $hook->{args} || {} } )};

            # Effects
            $args{$_} = $hook->{$_} for grep {exists $hook->{$_}} qw/effect effect_args/;

            push @fragments, \%args;
        }
        $response .= qq| $trigger="update( @{[ Jifty::JSON::objToJson( {actions => \@actions, fragments => \@fragments }, {singlequote => 1}) ]} );|;
        $response .= qq|return false;"|;
    }
    return $response;
}

=head2 class

Sets the CSS class that the element will display as

=head2 key_binding

Sets the key binding associated with this elements

=head2 id

Subclasses must override this to provide each element with a unique id.

=head2 label

Sets the label of the element.  This will be used for the key binding
legend, at very least.

=head2 render_key_binding

Adds the key binding for this input, if one exists.

=cut

sub render_key_binding {
    my $self = shift;
    my $key  = $self->key_binding;
    if ($key) {
        Jifty->web->out( "<script><!--\naddKeyBinding(" . "'"
                . uc($key) . "', "
                . "'click', " . "'"
                . $self->id . "'," . "'"
                . $self->label . "'"
                . ");\n-->\n</script>\n" );
    }
}

1;
