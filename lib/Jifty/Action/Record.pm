use warnings;
use strict;

package Jifty::Action::Record;

=head1 NAME

Jifty::Action::Record -- An action tied to a record in the database.

=head1 DESCRIPTION

Represents a web-based action that is a create, update, or delete of a
L<Jifty::Record> object.  This automatically populates the arguments
method of L<Jifty::Action> so that you don't need to bother.  

To actually use this class, you probably want to inherit from one of
L<Jifty::Action::Record::Create>, L<Jifty::Action::Record::Update>, or
L<Jifty::Action::Record::Delete> and override the C<record_class>
method.

=cut

use base qw/Jifty::Action/;

use Scalar::Util qw/ blessed /;

__PACKAGE__->mk_accessors(qw(record _cached_arguments));

=head1 METHODS

=head2 record

Access to the underlying L<Jifty::Record> object for this action is
through the C<record> accessor.

=head2 record_class

This method can either be overridden to return a string specifying the
name of the record class, or the name of the class can be passed to
the constructor.

=cut

sub record_class {
    my $self = shift;
    my $class = ref $self;
    my $hint = $class eq __PACKAGE__ ? "" :
        " (did you forget to override record_class in $class?)";
    $self->log->fatal("Jifty::Action::Record must be subclassed to be used" .
        $hint);
}

=head2 new PARAMHASH

Construct a new C<Jifty::Action::Record> (as mentioned in
L<Jifty::Action>, this should only be called by C<<
framework->new_action >>.  The C<record> value, if provided in the
PARAMHASH, will be used to load the L</record>; otherwise, the
parimary keys will be loaded from the action's argument values, and
the L</record> loaded from those primary keys.

=cut

sub new {
    my $class = shift;
    my %args  = (
        record => undef,
        @_,
    );
    my $self = $class->SUPER::new(%args);

    # Load the associated record class just in case it hasn't been already
    my $record_class = $self->record_class;
    Jifty::Util->require($record_class);

    # Die if we were given a record that wasn't a record
    if (ref $args{'record'} && !$args{'record'}->isa($record_class)) {
        Carp::confess($args{'record'}." isn't a $record_class");
    }

    # If the record class is a record, use that
    if ( ref $record_class ) {
        $self->record($record_class);
        $self->argument_value( $_, $self->record->$_ )
            for @{ $self->record->_primary_keys };
    } 

    # Otherwise, try to use the record passed to the constructor
    elsif ( ref $args{record} and $args{record}->isa($record_class) ) {
        $self->record( $args{record} );
        $self->argument_value( $_, $self->record->$_ )
            for @{ $self->record->_primary_keys };
    } 
    
    # Otherwise, try to use the arguments to load the record
    else {

        # We could leave out the explicit current user, but it'd have
        # a slight negative performance implications
        $self->record(
            $record_class->new( current_user => $self->current_user ) );
        my %given_pks = ();
        for my $pk ( @{ $self->record->_primary_keys } ) {
            $given_pks{$pk} = $self->argument_value($pk)
                if defined $self->argument_value($pk);
        }
        $self->record->load_by_primary_keys(%given_pks) if %given_pks;
    }

    return $self;
}

=head2 arguments

Overrides the L<Jifty::Action/arguments> method, to automatically
provide a form field for every writable attribute of the underlying
L</record>.

This also creates built-in validation and autocompletion methods
(validate_$fieldname and autocomplete_$fieldname) for action fields
that are defined "validate" or "autocomplete". These methods can
be overridden in any Action which inherits from this class.

Additionally, if our model class defines canonicalize_, validate_, or
autocomplete_ FIELD, generate appropriate an appropriate
canonicalizer, validator, or autocompleter that will call that method
with the value to be validated, canonicalized, or autocompleted.

C<validate_FIELD> should return a (success boolean, message) list.

C<autocomplete_FIELD> should return a the same kind of list as
L<Jifty::Action::_autocomplete_argument|Jifty::Action/_autocomplete_argument>

C<canonicalized_FIELD> should return the canonicalized value.

=cut

sub arguments {
    my $self = shift;

    # Don't do this twice, it's too expensive
    return $self->_cached_arguments if $self->_cached_arguments;

    # Get ready to rumble
    my $field_info = {};
    my @fields = $self->possible_fields;

    # we use a while here because we may be modifying the fields on the fly.
    while ( my $field = shift @fields ) {
        my $info = {};
        my $column;

        # The field is a column object, adjust to that
        if ( ref $field ) {
            $column = $field;
            $field  = $column->name;
        } 
        
        # Otherwise, we need to load the column info
        else {
            # Load teh column object and the record's current value
            $column = $self->record->column($field);
            my $current_value = $self->record->$field;

            # If the current value is actually a pointer to
            # another object, turn it into an ID
            $current_value = $current_value->id
                if blessed($current_value)
                and $current_value->isa('Jifty::Record');

            # The record's current value becomes the widget's default value
            $info->{default_value} = $current_value if $self->record->id;
        }

        # 
        #  if($field =~ /^(.*)_id$/ && $self->record->column($1)) {
        #    $column = $self->record->column($1);
        #}

    #########

        # Canonicalize the render_as setting for the column
        my $render_as = $column->render_as;
        $render_as = defined $render_as ? lc($render_as) : '';

        # Use a select box if we have a list of valid values
        if ( defined (my $valid_values = $column->valid_values)) {
            $info->{valid_values} = $valid_values;
            $info->{render_as}    = 'Select';
        } 
        
        # Use a checkbox for boolean fields
        elsif ( defined $column->type && $column->type =~ /^bool/i ) {
            $info->{render_as} = 'Checkbox';
        } 
        
        # Add an additional _confirm field for passwords
        elsif ( $render_as eq 'password' ) {

            # Add a validator to make sure both fields match
            my $same = sub {
                my ( $self, $value ) = @_;
                if ( $value ne $self->argument_value($field) ) {
                    return $self->validation_error(
                        ($field.'_confirm') => _("The passwords you typed didn't match each other")
                    );
                } else {
                    return $self->validation_ok( $field . '_confirm' );
                }
            };

            # Add the extra confirmation field
            $field_info->{ $field . "_confirm" } = {
                render_as => 'Password',
                virtual => '1',
                validator => $same,
                sort_order => ($column->sort_order +.01),
                mandatory => 0
            };
        }

        # Handle the X-to-one references
        elsif ( defined (my $refers_to = $column->refers_to) ) {

            # Render as a select box unless they override
            if ( UNIVERSAL::isa( $refers_to, 'Jifty::Record' ) ) {
                $info->{render_as} = $render_as || 'Select';
            }

            # If it's a select box, setup the available values
            if ( UNIVERSAL::isa( $refers_to, 'Jifty::Record' ) && $info->{render_as} eq 'Select' ) {

                # Get an unlimited collection
                my $collection = Jifty::Collection->new(
                    record_class => $refers_to,
                    current_user => $self->record->current_user,
                );
                $collection->unlimit;

                # Fetch the _brief_description() method
                my $method = $refers_to->_brief_description();

                # FIXME: we should get value_from with the actualy refered by key

                # Setup the list of valid values
                $info->{valid_values} = [
                    {   display_from => $refers_to->can($method) ? $method : "id",
                        value_from => 'id',
                        collection => $collection
                    }
                ];
            } 
            
            # If the reference is X-to-many instead, skip it
            else {
                # No need to generate arguments for
                # JDBI::Collections, as we can't do anything
                # useful with them yet, anyways.

                # However, if the column comes with a
                # "render_as", we can assume that the app
                # developer know what he/she is doing.
                # So we just render it as whatever specified.

                next unless $render_as;
            }
        }

    #########

        # Figure out what the action's validation method would for this field
        my $validate_method = "validate_" . $field;

        # Build up a validator sub if the column implements validation
        # and we're not overriding it at the action level
        if ( $column->validator and not $self->can($validate_method) ) {
            $info->{ajax_validates} = 1;
            $info->{validator} = sub {
                my $self  = shift;
                my $value = shift;

                # Check the column's validator
                my ( $is_valid, $message )
                    = &{ $column->validator }( $self->record, $value );

                # The validator reported valid, return OK
                if ($is_valid) {
                    return $self->validation_ok($field);
                } 
                
                # Bad stuff, report an error
                else {
                    unless ($message) {
                        $self->log->error(
                            qq{Schema validator for $field didn't explain why the value '$value' is invalid}
                        );
                    }
                    return (
                        $self->validation_error(
                            $field => ($message || _("That doesn't look right, but I don't know why"))
                        )
                    );
                }
            };
        }

        # What would the autocomplete method be for this column in the record
        my $autocomplete_method = "autocomplete_" . $field;

        # Set the autocompleter if the record has one
        if ( $self->record->can($autocomplete_method) ) {
            $info->{'autocompleter'} ||= sub {
                my ( $self, $value ) = @_;
                my %columns;
                $columns{$_} = $self->argument_value($_)
                    for grep { $_ ne $field } $self->possible_fields;
                return $self->record->$autocomplete_method( $value,
                    %columns );
            };
        }

        # The column requests an automagically generated autocompleter, which
        # is baed upon the values available in the field
        elsif ($column->autocompleted) {
            # Auto-generated autocompleter
            $info->{'autocompleter'} ||= sub {
                my ( $self, $value ) = @_;

                my $collection = Jifty::Collection->new(
                    record_class => $self->record_class,
                    current_user => $self->record->current_user
                );

                # Return the first 20 matches...
                $collection->unlimit;
                $collection->rows_per_page(20);

                # ...that start with the value typed...
                if (length $value) {
                    $collection->limit(
                        column   => $field, 
                        value    => $value, 
                        operator => 'STARTSWITH', 
                        entry_aggregator => 'AND'
                    );
                }

                # ...but are not NULL...
                $collection->limit(
                    column => $field, 
                    value => 'NULL', 
                    operator => 'IS NOT', 
                    entry_aggregator => 'AND'
                );

                # ...and are not empty.
                $collection->limit(
                    column => $field, 
                    value => '', 
                    operator => '!=', 
                    entry_aggregator => 'AND'
                );

                # Optimize the query a little bit
                $collection->columns('id', $field);
                $collection->order_by(column => $field);
                $collection->group_by(column => $field);

                # Set up the list of choices to return
                my @choices;
                while (my $record = $collection->next) {
                    push @choices, $record->$field;
                }
                return @choices;
            };
        }

        # Add a canonicalizer for the column if the record provides one
        if ( $self->record->has_canonicalizer_for_column($field) ) {
            $info->{'ajax_canonicalizes'} = 1;
            $info->{'canonicalizer'} ||= sub {
                my ( $self, $value ) = @_;
                return $self->record->run_canonicalization_for_column(column => $field, value => $value);
            };
        } 
        
        # Otherwise, if it's a date, we have a built-in canonicalizer for that
        elsif ( $render_as eq 'date') {
            $info->{'ajax_canonicalizes'} = 1;
        }

        # If we're hand-coding a render_as, hints or label, let's use it.
        for (qw(render_as label hints max_length mandatory sort_order container)) {

            if ( defined (my $val = $column->$_) ) {
                $info->{$_} = $val;
            }
        }
        $field_info->{$field} = $info;
    }

    # After all that, use the schema { ... } params for the final bits
    if ($self->can('PARAMS')) {

        # User-defined declarative schema fields can override default ones here
        my $params = $self->PARAMS;

        # We really, really want our sort_order to prevail over user-defined ones
        # (as opposed to all other param fields).  So we do exactly that here.
        while (my ($key, $param) = each %$params) {
            defined(my $sort_order = $param->sort_order) or next;

            # The .99 below means that it's autogenerated by Jifty::Param::Schema.
            if ($sort_order =~ /\.99$/) {
                $param->sort_order($field_info->{$key}{sort_order});
            }
        }

        # Cache the result of merging the Jifty::Action::Record and schema
        # parameters
        use Jifty::Param::Schema ();
        $self->_cached_arguments(Jifty::Param::Schema::merge_params($field_info, $params));
    }

    # No schema { ... } block, so just use what we generated
    else {
        $self->_cached_arguments($field_info);
    }

    return $self->_cached_arguments();
}

=head2 possible_fields

Returns the list of fields on the object that the action can update.
This defaults to all of the fields of the object.

=cut

sub possible_fields {
    my $self = shift;
    return map { $_->name } grep { $_->container || $_->type ne "serial" } $self->record->columns;
}

=head2 take_action

Throws an error unless it is overridden; use
Jifty::Action::Record::Create, ::Update, or ::Delete

=cut

sub take_action {
    my $self = shift;
    $self->log->fatal(
        "Use one of the Jifty::Action::Record subclasses, ::Create, ::Update or ::Delete or ::Search"
    );
}

sub _setup_event_before_action {
    my $self = shift;

    # Setup the information regarding the event for later publishing
    my $event_info = {};
    $event_info->{as_hash_before} = $self->record->as_hash;
    $event_info->{record_id} = $self->record->id;
    $event_info->{record_class} = ref($self->record);
    $event_info->{action_class} = ref($self);
    $event_info->{action_arguments} = $self->argument_values; # XXX does this work?
    $event_info->{current_user_id} = $self->current_user->id || 0;
    return ($event_info);
}

sub _setup_event_after_action {
    my $self = shift;
    my $event_info = shift;

    # Add a few more bits about the result
    $event_info->{result} = $self->result;    
    $event_info->{timestamp} = time(); 
    $event_info->{as_hash_after} = $self->record->as_hash;

    # Publish the event
    my $event_class = $event_info->{'record_class'};
    $event_class =~ s/::Model::/::Event::Model::/g;
    Jifty::Util->require($event_class);
    $event_class->new($event_info)->publish;
}

=head1 SEE ALSO

L<Jifty::Action>, L<Jifty::Record>, L<Jifty::DBI::Record>,
L<Jifty::Action::Record::Create>, L<Jifty::Action::Record::Update>,
L<Jifty::Action::Record::Delete>

=head1 LICENSE

Jifty is Copyright 2005-2006 Best Practical Solutions, LLC.
Jifty is distributed under the same terms as Perl itself.

=cut

1;
