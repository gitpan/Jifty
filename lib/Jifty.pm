use warnings;
use strict;

package Jifty;
use encoding 'utf8';
# Work around the fact that Time::Local caches thing on first require
BEGIN { local $ENV{'TZ'} = "GMT";  require Time::Local;}
$Jifty::VERSION = '0.60912';

=head1 NAME

Jifty - an application framework

=head1 DESCRIPTION

Yet another web framework.

=head2 What's cool about Jifty? (Buzzwords)

=over 4

=item DRY (Don't Repeat Yourself)

Jifty tries not to make you say things more than once.

=item Full-stack

Out of the proverbial box, Jifty comes with one way to do everything
you should need to do: One database mapper, one templating system, one
web services layer, one AJAX toolkit, one set of handlers for
standalone or FastCGI servers. We work hard to make all the bits play
well together, so you don't have to.

=item Continuations

With Jifty, it's easy to let the user go off and do something else,
like fill out a wizard, look something up in the help system or go
twiddle their preferences and come right back to where they were.

=item Form-based dispatch

This is one of the things that Jifty does that we've not seen anywhere
else. Jifty owns your form rendering and processing. This means you
never need to write form handling logic. All you say is "I want an
input for this argument here" and Jifty takes care of the rest. (Even
autocomplete and validation)

=item A Pony

Jifty is the only web application framework that comes with a pony.

=back

=head2 Introduction

If this is your first time using Jifty, L<Jifty::Manual::Tutorial> is
probably a better place to start.

=cut


use base qw/Jifty::Object/;
use Jifty::Everything;

use vars qw/$HANDLE $CONFIG $LOGGER $HANDLER $API $CLASS_LOADER @PLUGINS/;

=head1 METHODS

=head2 new PARAMHASH

This class method instantiates a new C<Jifty> object. This object
deals with configuration files, logging and database handles for the
system.  Before this method returns, it calls the application's C<start>
method (i.e. C<MyApp->start>) to handle any application-specific startup.

Most of the time, the server will call this for you to set up
your C<Jifty> object.  If you are writing command-line programs that
want to use your libraries (as opposed to web services) you will need
to call this yourself.

See L<Jifty::Config> for details on how to configure your Jifty
application.

=head3 Arguments

=over

=item no_handle

If this is set to true, Jifty will not create a L<Jifty::Handle> and
connect to a database.  Only use this if you're about to drop the
database or do something extreme like that; most of Jifty expects the
handle to exist.  Defaults to false.

=item logger_component

The name that Jifty::Logger will log under.  If you don't specify anything
Jifty::Logger will log under the empty string.  See L<Jifty::Logger> for
more infomation.

=back

=cut

sub new {
    my $ignored_class = shift;

    my %args = (
        no_handle        => 0,
        logger_component => undef,
        @_
    );

    # Load the configuration. stash it in ->config
    Jifty->config( Jifty::Config->new() );

    Jifty::I18N->new(); # can't do this before we have the config set up

    # Now that we've loaded the configuration, we can remove the temporary 
    # Jifty::DBI::Record baseclass for records and insert our "real" baseclass,
    # which is likely Record::Cachable or Record::Memcached
    pop @Jifty::Record::ISA;
    Jifty::Util->require( Jifty->config->framework('Database')->{'RecordBaseClass'});
    push @Jifty::Record::ISA, Jifty->config->framework('Database')->{'RecordBaseClass'};

    Jifty->logger( Jifty::Logger->new( $args{'logger_component'} ) );

    # Set up plugins
    my @plugins;
    for my $plugin (@{Jifty->config->framework('Plugins')}) {
        my $class = "Jifty::Plugin::".(keys %{$plugin})[0];
        my %options = %{ $plugin->{(keys %{$plugin})[0]} };
        Jifty::Util->require($class);
        Jifty::ClassLoader->new(base => $class)->require;
        push @plugins, $class->new(%options);
    }

    # Get a classloader set up
    my $class_loader = Jifty::ClassLoader->new(
        base => Jifty->config->framework('ApplicationClass')
    );

    Jifty->class_loader($class_loader);
    $class_loader->require;

    Jifty->plugins(@plugins);
    Jifty->handler(Jifty::Handler->new());
    Jifty->api(Jifty::API->new());

    # Let's get the database rocking and rolling
    Jifty->setup_database_connection(%args);

    # Call the application's start method to let it do anything
    # application specific for startup
    my $app = Jifty->config->framework('ApplicationClass');
    
    $app->start()
        if $app->can('start');
    
}

=head2 config

An accessor for the L<Jifty::Config> object that stores the
configuration for the Jifty application.

=cut

sub config {
    my $class = shift;
    $CONFIG = shift if (@_);
    return $CONFIG;
}

=head2 logger

An accessor for our L<Jifty::Logger> object for the application.

=cut

sub logger {
    my $class = shift;
    $LOGGER = shift if (@_);
    return $LOGGER;
}

=head2 handler

An accessor for our L<Jifty::Handler> object.

=cut

sub handler {
    my $class = shift;
    $HANDLER = shift if (@_);
    return $HANDLER;
}

=head2 handle

An accessor for the L<Jifty::Handle> object that stores the database
handle for the application.

=cut

sub handle {
    my $class = shift;
    $HANDLE = shift if (@_);
    return $HANDLE;
}

=head2 api

An accessor for the L<Jifty::API> object that publishes and controls
information about the application's L<Jifty::Action>s.

=cut

sub api {
    my $class = shift;
    $API = shift if (@_);
    return $API;
}

=head2 web

An accessor for the L<Jifty::Web> object that the web interface uses. 

=cut

sub web {
    $HTML::Mason::Commands::JiftyWeb ||= Jifty::Web->new();
    return $HTML::Mason::Commands::JiftyWeb;
}

=head2 plugins

Returns a list of L<Jifty::Plugin> objects for this Jifty application.

=cut

sub plugins {
    my $class = shift;
    @PLUGINS = @_ if @_;
    return @PLUGINS;
}

=head2 class_loader

An accessor for the L<Jifty::ClassLoader> object that stores the loaded
classes for the application.

=cut

sub class_loader {
    my $class = shift;
    $CLASS_LOADER = shift if (@_);
    return $CLASS_LOADER;
}

=head2 setup_database_connection

Set up our database connection. Optionally takes a param hash with a
single argument.  This method is automatically called by L</new>.

=over

=item no_handle

Defaults to false. If true, Jifty won't try to set up a database handle

=back


If C<no_handle> is set or our application's config file is missing a C<Database> configuration
 section or I<has> a C<SkipDatabase: 1> directive in its framework configuration, does nothing.

=cut

sub setup_database_connection {
    my $self = shift;
    my %args = (no_handle =>0,
                @_);
    unless ( $args{'no_handle'}
        or Jifty->config->framework('SkipDatabase')
        or not Jifty->config->framework('Database') )
    {

        my $handle_class = (Jifty->config->framework('ApplicationClass') . "::Handle");
        Jifty::Util->require( $handle_class );
        Jifty->handle( $handle_class->new );
        Jifty->handle->connect();
        Jifty->handle->check_schema_version();
    }
}

=head1 LICENSE

Jifty is Copyright 2005 Best Practical Solutions, LLC.
Jifty is distributed under the same terms as Perl itself.

=head1 SEE ALSO

L<http://jifty.org>

=head1 AUTHORS

Jesse Vincent, Alex Vandiver and David Glasser.


=cut

1;
