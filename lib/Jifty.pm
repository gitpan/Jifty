use warnings;
use strict;

package Jifty;

our $VERSION = '0.51225';

=head1 NAME

Jifty -- Just Do It

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

use Jifty::Everything;
use UNIVERSAL::require;

use base qw/Jifty::Object/;

use vars qw/$HANDLE $CONFIG $LOGGER/;

=head1 METHODS

=head2 new PARAMHASH

This class method instantiates a new C<Jifty> object. This object
deals with configuration files, logging and database handles for the
system.  Most of the time, the server will call this for you to set up
your C<Jifty> object.  If you are writing command-line programs htat
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
    __PACKAGE__->config( Jifty::Config->new() );
    __PACKAGE__->logger( Jifty::Logger->new( $args{'logger_component'} ) );

    my $loader = Jifty::ClassLoader->new();
    $loader->require;

    unless ( $args{'no_handle'} or not Jifty->config->framework('Database') )
    {
        Jifty->handle( Jifty::Handle->new() );
        Jifty->handle->connect();
        Jifty->handle->check_schema_version();
    }

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

=head2 handle

An accessor for the L<Jifty::Handle> object that stores the database
handle for the application.

=cut

sub handle {
    my $class = shift;
    $HANDLE = shift if (@_);
    return $HANDLE;
}

=head2 web

An accessor for the L<Jifty::Web> object that the web interface uses.

=cut

sub web {
    $HTML::Mason::Commands::JiftyWeb ||= Jifty::Web->new();
    return $HTML::Mason::Commands::JiftyWeb;
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
