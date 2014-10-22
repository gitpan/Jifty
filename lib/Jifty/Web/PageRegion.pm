use warnings;
use strict;
 
package Jifty::Web::PageRegion;

=head1 NAME

Jifty::Web::PageRegion - Defines a page region

=head1 DESCRIPTION

Describes a region of the page which contains a mason fragment which
can be updated via AJAX or via query parameters.

=cut

use base qw/Jifty::Object Class::Accessor::Fast/;
__PACKAGE__->mk_accessors(qw(name default_path default_arguments qualified_name parent region_wrapper));
use Jifty::JSON;

=head2 new PARAMHASH

Creates a new page region.  The possible arguments in the C<PARAMHASH>
are:

=over

=item name

The (unqualified) name of the region.  This is used to generate a
unique id -- it should consist of only letters and numbers.

=item path

The path to the fragment that this page region contains.  Defaults to
C</__jifty/empty>, which, as its name implies, is empty.

=item defaults (optional)

Specifies an optional set of parameter defaults.  These should all be
simple scalars, as they might be passed across HTTP if AJAX is used.

=item parent (optional)

The parent L<Jifty::Web::PageRegion> that this region is enclosed in.

=item region_wrapper (optional)

A boolean; whether or not the region, when rendered, will include the
HTML region preamble that makes Javascript aware of its presence.
Defaults to true.

=back

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    my %args = (
                name => undef,
                path => "/__jifty/empty",
                defaults => {},
                parent => undef,
                region_wrapper => 1,
                @_
               );

    # Name is required
    if (not defined $args{name}) {
        warn "Name is required for page regions.";
        return;
    }

    # References don't go over HTTP very well
    if (grep {ref $_} values %{$args{defaults}}) {
        warn "Reference '$args{defaults}{$_}' passed as default for '$_' to region '$args{name}'"
          for grep {ref $args{defaults}{$_}} keys %{$args{defaults}};
        return;
    }

    $self->name($args{name});
    $self->qualified_name(Jifty->web->qualified_region($self));
    $self->default_path($args{path});
    $self->default_arguments($args{defaults});
    $self->arguments({});
    $self->parent($args{parent} || Jifty->web->current_region);
    $self->region_wrapper($args{region_wrapper});

    # Keep track of the fully qualified name (which should be unique)
    $self->log->warn("Repeated region: " . $self->qualified_name)
        if Jifty->web->get_region( $self->qualified_name );
    Jifty->web->{'regions'}{ $self->qualified_name } = $self;

    return $self;
}

=head2 name [NAME]

Gets or sets the name of the page region.

=cut

=head2 qualified_name [NAME]

Gets or sets the fully qualified name of the page region.  This should
be unique on a page.  This is usually set by L</enter>, based on the
page regions that this region is inside.  See
L<Jifty::Web/qualified_region>.

=cut

=head2 default_path [PATH]

Gets or sets the default path of the fragment.  This is overridden by
L</path>.

=cut

=head2 path [PATH]

Gets or sets the path that the fragment actually contains.  This
overrides L</default_path>.

=cut

sub path {
    my $self = shift;
    $self->{path} = shift if @_;
    return $self->{path} || $self->default_path;
}

=head2 default_argument NAME [VALUE]

Gets or sets the default value of the C<NAME> argument.  This is used
as a fallback, and also to allow generated links to minimize the
amount of state they must transmit.

=cut

sub default_argument {
    my $self = shift;
    my $name = shift;
    $self->{default_arguments}{$name} = shift if @_;
    return $self->{default_arguments}{$name} || '';
}

=head2 argument NAME [VALUE]

Gets or sets the actual run-time value of the page region.  This
usually comes from HTTP parameters.  It overrides the
L</default_argument> of the same C<NAME>.

=cut

sub argument {
    my $self = shift;
    my $name = shift;
    $self->{arguments}{$name} = shift if @_;
    return $self->{arguments}{$name} || $self->default_argument($name);
}

=head2 arguments [HASHREF]

Sets all arguments at once, or returns all arguments.  The latter will
also include all default arguments.

=cut

sub arguments {
    my $self = shift;
    $self->{arguments} = shift if @_;
    return { %{$self->{default_arguments}}, %{$self->{arguments}}};
}

=head2 enter

Enters the region; this sets the qualified name based on
L<Jifty::Web/qualified_region>, and uses that to pull runtime values
for the L</path> and L</argument>s from the
L<Jifty::Request/state_variables>.

=cut

sub enter {
    my $self = shift;

    # Add ourselves to the region stack
    push @{Jifty->web->{'region_stack'}}, $self;

    # Merge in the settings passed in via state variables
    for (Jifty->web->request->state_variables) {
        if ($_->key =~ /^region-(.*?)\.(.*)/ and $1 eq $self->qualified_name and $_->value ne $self->default_argument($2)) {
            $self->argument($2 => $_->value);
            Jifty->web->set_variable("region-$1.$2" => $_->value);
        }
        if ($_->key =~ /^region-(.*?)$/ and $1 eq $self->qualified_name and $_->value ne $self->default_path) {
            $self->path($_->value);
            Jifty->web->set_variable("region-$1" => $_->value);
        }
    }
}

=head2 exit 

Exits the page region, if it is the most recent one.  Normally, you
won't need to call this by hand; however, if you are calling L</enter>
by hand, you will need to call the corresponding C<exit>.

=cut

sub exit {
    my $self = shift;

    if (Jifty->web->current_region != $self) {
        $self->log->warn("Attempted to exit page region ".$self->qualified_name." when it wasn't the most recent");
    } else {
        pop @{Jifty->web->{'region_stack'}};
    }
}

=head2 as_string

Deals with the bulk of the effort to show a page region.  Returns a
string of the fragment and associated javascript (if any).

=cut

sub as_string {
    my $self = shift;

    if (Jifty->web->current_region ne $self) {
        # XXX TODO: Possibly we should just call ->enter
        warn "Attempt to call as_string on a region which is not the current region";
        return "";
    }
    
    my %arguments = %{ $self->arguments };

    # undef arguments cause warnings. We hatesses the warnings, we do.
    defined $arguments{$_} or delete $arguments{$_} for keys %arguments;
    my $result = "";

    # We need to tell the browser this is a region and what its
    # default arguments are as well as the path of the "fragment".  We
    # do this by passing in a snippet of javascript which encodes this
    # information.  We only render this region wrapper if we're asked
    # to (which is true by default)
    if ( $self->region_wrapper ) {
        $result .= qq|<script type="text/javascript">\n|
            . qq|new Region('| . $self->qualified_name . qq|',|
            . Jifty::JSON::objToJson( \%arguments, { singlequote => 1 } ) . qq|,| 
            . qq|'| . $self->path . qq|',|
            . ( $self->parent ? qq|'| . $self->parent->qualified_name . qq|'| : q|null|)
            . qq|);\n|
            . qq|</script>|
            . qq|<div id="region-| . $self->qualified_name . qq|">|;
    }

    # Make a fake request and throw it at the dispatcher
    my $subrequest = Jifty->web->request->clone;
    $subrequest->argument( region => $self );
    $subrequest->argument( $_ => $arguments{$_}) for keys %arguments;
    $subrequest->path( $self->path );
    $subrequest->top_request( Jifty->web->request->top_request );

    # Remove all of the actions
    $subrequest->clear_actions;
    local Jifty->web->{request} = $subrequest;

    # While we're inside this region, have Mason to tack its response
    # onto a variable and not send headers when it does so
    #XXX TODO: There's gotta be a better way to localize it
    my $region_content = '';
    Jifty->handler->mason->interp->out_method( \$region_content );

    # Call into the dispatcher
    Jifty->handler->dispatcher->handle_request;
    $result .= $region_content;
    $result .= qq|</div>| if ( $self->region_wrapper );

    Jifty->handler->mason->interp->out_method( \&Jifty::View::Mason::Handler::out_method );

    return $result;
}

=head2 render

Calls L</enter>, outputs the results of L</as_string>, and then calls
L</exit>.  Returns an empty string.

=cut

sub render {
    my $self = shift;

    $self->enter;
    Jifty->web->out($self->as_string);
    $self->exit;
    "";
}

=head2 get_element [RULES]

Returns a CSS2 selector which selects only elements under this region
which fit the C<RULES>.  This method is used by AJAX code to specify
where to add new regions.

=cut

sub get_element {
    my $self = shift;
    return "#region-" . $self->qualified_name . ' ' . join(' ', @_);
}

1;
