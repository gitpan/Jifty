use warnings;
use strict;

package Jifty::ClassLoader;

=head1 NAME

Jifty::ClassLoader - Loads the application classes

=head1 DESCRIPTION

C<Jifty::ClassLoader> loads all of the application's model and action
classes, generating classes on the fly for Collections of pre-existing
models.

=head2 new

Returns a new ClassLoader object.  Doing this installs a hook into
C<@INC> that allows L<Jifty::ClassLoader> to dynamically create
needed classes if they do not exist already.  This works because if
use/require encounters a blessed reference in C<@INC>, it will
invoke the INC method with the name of the module it is searching
for on the reference.

Takes one mandatory argument, C<base>, which should be the the
application's or a plugin's base path; all of the classes under this will be
automatically loaded.

L<Jifty::ClassLoader> objects are singletons per C<base>. If you call C<new> and a class loader for the given base has already been initialized, this will return a reference to that object rather than creating a new one.

=cut

sub new {
    my $class = shift;
    my %args = @_;

    # Check to make sure this classloader hasn't been built yet and stop if so
    my @exist = grep {ref $_ eq $class and $_->{base} eq $args{base}} @INC;
    return $exist[0] if @exist;

    # It's a new one, build it
    my $self = bless {%args}, $class;
    push @INC, $self;
    return $self;
}

=head2 INC

The hook that is called when a module has been C<require>'d that
cannot be found on disk.  The following stub classes are
auto-generated the class loader. 

Here the "I<Application>" indicates the name of the application the class loader is being applied to. However, this really just refers to the C<base> argument passed to the constructor, so it could refer to a plugin class or just about anything else.

=over

=item I<Application>

An empty application base class is created that doen't provide any
methods or inherit from anything.

=item I<Application>::Action

An empty class that descends from L<Jifty::Action>.

=item I<Application>::Action::I<[Verb]>I<[Something]>

If I<Application>::Model::I<Something> is a valid model class and I<Verb> is one of "Create", "Search", "Update", or "Delete", then it creates a subclass of I<Application>::Action::Record::I<Verb>

=item I<Application>::Action::I<Something>

The class loader will search for a plugin I<Plugin> such that I<Plugin>::Action::I<Something> exists. It will then create an empty class named I<Application>::Action::I<Something> that descends from I<Plugin>::Action::I<Something>.

This means that a plugin may be written to allow the application to override the default implementation used by the plugin as long as the plugin uses the application version of the class.

=item I<Application>::Action::Record::I<Something>

An empty class that descends from the matching Jifty class, Jifty::Action::Record::I<Something>. This is generally used to build application-specific descendants of L<Jifty::Action::Record::Create>, L<Jifty::Action::Record::Search>, L<Jifty::Action::Record::Update>, or L<Jifty::Action::Record::Delete>.

=item I<Application>::Bootstrap

An empty class that descends from L<Jifty::Bootstrap>.

=item I<Application>::Collection

An empty class that descends from L<Jifty::Collection> is created.

=item I<Application>::CurrentUser

An empty class that descends from L<Jifty::CurrentUser>.

=item I<Application>::Dispatcher

An empty class that descends from L<Jifty::Dispatcher>.

=item I<Application>::Event

An empty class that descends from L<Jifty::Event> is created.

=item I<Application>::Event::Model

An empty class that descents from L<Jifty::Event::Model> is created.

=item I<Application>::Event::Model::I<Something>

If I<Application>::Model::I<Something> is a valid model class, then it creates an empty descendant of I<Application>::Event::Model with the C<record_class> set to I<Application>::Model::I<Something>.

=item I<Application>::Handle

An empty class that descends from L<Jifty::Handle> is created.

=item I<Application>::Model::I<Something>Collection

If C<I<Application>::Model::I<Something>> is a valid model class, then
it creates a subclass of L<Jifty::Collection> whose C<record_class> is
C<I<Application>::Model::I<Something>>.

=item I<Application>::Notification

An empty class that descends from L<Jifty::Notification>.

=item I<Application>::Notification::I<Something>

The class loader will search for a plugin I<Plugin> such that I<Plugin>::Notification::I<Something> exists. It will then create an empty class named I<Application>::Notification::I<Something> that descends from I<Plugin>::Notification::I<Something>.

This allows an application to customize the email notification sent out by a plugin as long as the plugin defers to the application version of the class.

=item I<Application>::Record

An empty class that descends from L<Jifty::Record> is created.

=item I<Application>::Upgrade

An empty class that descends from L<Jifty::Upgrade>.

=item I<Application>::View

An empty class that descends from L<Jifty::View::Declare>.

=back

=cut

# This subroutine's name is fully qualified, as perl will ignore a 'sub INC'
sub Jifty::ClassLoader::INC {
    my ( $self, $module ) = @_;
    my $base = $self->{base};
    return undef unless ( $module and $base );

    # Canonicalize $module to :: style rather than / and .pm style;
    $module =~ s/.pm$//;
    $module =~ s{/}{::}g;

    # The quick check. We only want to handle things for our app
    return undef unless $module =~ /^$base/;

    # If the module is the same as the base, build the application class
    if ( $module =~ /^(?:$base)$/ ) {
        return $self->return_class( "package " . $base . ";\n");
    }

    # Handle most of the standard App::Class ISA Jifty::Class
    elsif ( $module =~ /^(?:$base)::(Record|Collection|Notification|
                                      Dispatcher|Bootstrap|Upgrade|CurrentUser|
                                      Handle|Event|Event::Model|Action|
                                      Action::Record::\w+)$/x ) {
        return $self->return_class(
                  "package $module;\n"
                . "use base qw/Jifty::$1/; sub _autogenerated { 1 };\n"
            );
    } 
    
    # Autogenerate an empty View if none is defined
    elsif ( $module =~ /^(?:$base)::View$/ ) {
        return $self->return_class(
                  "package $module;\n"
                . "use Jifty::View::Declare -base; sub _autogenerated { 1 };\n"
            );
    } 
    
    # Autogenerate the Collection class for a Model
    elsif ( $module =~ /^(?:$base)::Model::([^\.]+)Collection$/ ) {
        return $self->return_class(
                  "package $module;\n"
                . "use base qw/@{[$base]}::Collection/;\n"
                . "sub record_class { '@{[$base]}::Model::$1' }\n"
                . "sub _autogenerated { 1 };\n"
            );
    } 
    
    # Autogenerate the the event class for model changes
    elsif ( $module =~ /^(?:$base)::Event::Model::([^\.]+)$/ ) {
        
        # Determine the model class and load it
        my $modelclass = $base . "::Model::" . $1;
        Jifty::Util->require($modelclass);

        # Don't generate an event unless it really is a model
        return undef unless eval { $modelclass->isa('Jifty::Record') };

        return $self->return_class(
                  "package $module;\n"
                . "use base qw/${base}::Event::Model/;\n"
                . "sub record_class { '$modelclass' };\n"
                . "sub _autogenerated { 1 };\n"
            );
    } 
    
    # Autogenerate the record actions for a model
    elsif ( $module =~ /^(?:$base)::Action::
                        (Create|Update|Delete|Search)([^\.]+)$/x ) {

        # Determine the model class and load it
        my $modelclass = $base . "::Model::" . $2;
        Jifty::Util->_require( module => $modelclass, quiet => 1);

        # Don't generate the action unless it really is a model
        if ( eval { $modelclass->isa('Jifty::Record') } ) {

            return $self->return_class(
                  "package $module;\n"
                . "use base qw/$base\::Action::Record::$1/;\n"
                . "sub record_class { '$modelclass' };\n"
                . "sub _autogenerated { 1 };\n"
            );
        }

    }

    # This is a little hard to grok, so pay attention. This next if checks to
    # see if the requested class belongs to an application (i.e., this class
    # loader does not belong to a plugin). If so, it will attempt to create an
    # application override of a plugin class, if the plugin provides the same
    # type of notification or action.
    #
    # This allows the application to customize what happens on a plugin action
    # or customize the email notification sent by a plugin. 
    #
    # However, this depends on the plugin being well-behaved and always using
    # the application version of actions and notifications rather than trying
    # to use the plugin class directly.
    #
    # Of course, if the class loader finds such a case, then the application
    # has not chosen to override it and we're generating the empty stub to take
    # it's place.

    # N.B. This is if and not elsif on purpose. If the class name requested is
    # App::Action::(Create|Update|Search|Delete)Thing, but there is no such
    # model as App::Model::Thing, we may be trying to create a sub-class of
    # Plugin::Action::(Create|Update|Search|Delete)Thing for
    # Plugin::Model::Thing instead.
    
    # Requesting an application override of a plugin action or notification?
    if ( $module =~ /^(?:$base)::(Action|Notification)::(.*)$/x and not grep {$_ eq $base} map {ref} Jifty->plugins ) {
        my $type = $1;
        my $item = $2;

        # Find a plugin with a matching action or notification
        foreach my $plugin (map {ref} Jifty->plugins) {
            next if ($plugin eq $base);
            my $class = $plugin."::".$type."::".$item;

            # Found it! Generate the empty stub.
            if (Jifty::Util->try_to_require($class) ) {
                return $self->return_class(
                        "package $module;\n"
                        . "use base qw/$class/;\n"
                        . "sub _autogenerated { 1 };\n"
                    );
            }
        }
    }

    # Didn't find a match
    return undef;
}

=head2 return_class CODE

A helper method; takes CODE as a string and returns an open filehandle
containing that CODE.

=cut

sub return_class {
    my $self = shift;
    my $content = shift;

    # ALWAYS use warnings; use strict!!!
    $content = "use warnings; use strict; ". $content  . "\n1;";

    # Magically turn the text into a file handle
    open my $fh, '<', \$content;
    return $fh;
}

=head2 require

Loads all of the application's Actions and Models.  It additionally
C<require>'s all Collections and Create/Update actions for each Model
base class -- which will auto-create them using the above code if they
do not exist on disk.

=cut

sub require {
    my $self = shift;
    my $base = $self->{base};

    # XXX It would be nice to have a comment here or somewhere in here
    # indicating when it's possible for a class loader to be missing it's base.
    # This is a consistent check in the class loader, but I don't know of an
    # example where this would be the case. -- Sterling

    # if we don't even have an application class, this trick will not work
    return unless ($base);

    # Always require the base and the base current user first
    Jifty::Util->require($base);
    Jifty::Util->require($base."::CurrentUser");

    # Use Module::Pluggable to help locate our models, actions, notifications,
    # and events
    Jifty::Module::Pluggable->import(
        # $base goes last so we pull in the view class AFTER the model classes
        search_path => [map { $base . "::" . $_ } ('Model', 'Action', 'Notification', 'Event')],
        require => 0,
        except  => qr/\.#/,
        inner   => 0
    );
    
    # Construct the list of models for the application for later reference
    my %models;
    for ($self->plugins) {
        Jifty::Util->require($_);  
    }
    $models{$_} = 1 for grep {/^($base)::Model::(.*)$/ and not /Collection(?:$||\:\:)/} $self->plugins;
    $self->models(sort keys %models);

    # Load all those models and model-related actions, notifications, and events
    for my $full ($self->models) {
        $self->_require_model_related_classes($full);
    }
    $_->finalize_triggers for grep {$_->can('finalize_triggers')} $self->models;
}

# This class helps Jifty::ClassLoader::require() load each model, the model's
# collection and the model's create, update, delete, and search actions.
sub _require_model_related_classes {
    my $self = shift;
    my $full = shift;
    my $base = $self->{base};
    my($short) = $full =~ /::Model::(\w*)/;
    Jifty::Util->require($full . "Collection");
    Jifty::Util->require($base . "::Action::" . $_ . $short)
        for qw/Create Update Delete Search/;
}


=head2 require_classes_from_database

Jifty supports model classes that aren't files on disk but instead records
in your database. It's a little bit mind bending, but basically, you can
build an application entirely out of the database without ever writing a
line of code(*).

* As of early 2007, this forward looking statement is mostly a lie. But we're
working on it.

This method finds all database-backed models and instantiates jifty classes for
them it returns a list of classnames of the models it created.

=cut

# XXX TODO FIXME Holy crap! This is in the trunk! See the virtual-models branch
# of Jifty if you really want to see this in action (unless it's finally been
# merged intot he trunk), which isn't the case as of August 13, 2007. 
# -- Sterling
sub require_classes_from_database {
    my $self = shift;
    my @instantiated;

    require Jifty::Model::ModelClassCollection;
    require Jifty::Model::ModelClass;
    my $models = Jifty::Model::ModelClassCollection->new(current_user => Jifty::CurrentUser->superuser);
    $models->unlimit();
    while (my $model = $models->next) {
        $model->instantiate();
        $self->_require_model_related_classes($model->qualified_class);
    }
}

=head2 require_views

Load up C<$appname::View>, the view class for the application.

=cut

sub require_views {
    my $self = shift;
    my $base = $self->{base};

    # if we don't even have an application class, this trick will not work
    return unless ($base);
    Jifty::Util->require($base."::View");
}

=head2 models

Accessor to the list of models this application has loaded.

In scalar context, returns a mutable array reference; in list context,
return the content of the array.

=cut

sub models {
    my $self = shift;

    # If we have args, update the list of models
    if (@_) {
        $self->{models} = ref($_[0]) ? $_[0] : \@_;
    }

    # DWIM: return an array if they want a list, return an arrayref otherwise
    wantarray ? @{ $self->{models} ||= [] } : $self->{models};
}

=head2 DESTROY

When the ClassLoader gets garbage-collected, its entry in @INC needs
to be removed.

=cut

# The entries in @INC end up having SvTYPE == SVt_RV, but SvRV(sv) ==
# 0x0 and !SvROK(sv) (!?)  This may be something that perl should cope
# with more cleanly.
#
# We call this explictly in an END block in Jifty.pm, because
# otherwise the DESTROY block gets called *after* there's already a
# bogus entry in @INC

# This bug manifests itself as warnings that look like this:

# Use of uninitialized value in require at /tmp/7730 line 9 during global destruction.

sub DESTROY {
    my $self = shift;
    @INC = grep {defined $_ and $_ ne $self} @INC;
}

=head1 WRITING YOUR OWN CLASSES

If you require more functionality than is provided by the classes created by
ClassLoader (which you'll almost certainly need to do if you want an
application that does more than display a pretty Pony) then you should create a
class with the appropriate name and add your extra logic to it.

For example you will almost certainly want to write your own
dispatcher, so something like:

 package MyApp::Dispatcher;
 use Jifty::Dispatcher -base;

If you want to add some application specific behaviour to a model's
collection class, say for the User model, create F<UserCollection.pm>
in your applications Model directory.

 package MyApp::Model::UserCollection;
 use base 'MyApp::Collection';

=head1 SEE ALSO

L<Jifty> and just about every other class that this provides an empty override for.

=head1 LICENSE

Jifty is Copyright 2005-2007 Best Practical Solutions, LLC.
Jifty is distributed under the same terms as Perl itself.

=cut

1;
