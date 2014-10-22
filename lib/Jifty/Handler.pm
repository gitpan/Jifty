use strict;
use warnings;

package Jifty::Handler;

=head1 NAME

Jifty::Handler - Methods related to the Mason handler

=head1 SYNOPSIS

  use Jifty;
  Jifty->new();

  my $handler = Jifty::Handler->handle_request( cgi => $cgi );

  # after each request is handled
  Jifty::Handler->cleanup_request;

=head1 DESCRIPTION

L<Jifty::Handler> provides methods required to deal with Mason CGI
handlers.  

=cut

use base qw/Class::Accessor::Fast/;
use Module::Refresh ();
use Jifty::View::Declare::Handler ();

BEGIN {
    # Creating a new CGI object breaks FastCGI in all sorts of painful
    # ways.  So wrap the call and preempt it if we already have one
    use CGI ();

    # If this file gets reloaded using Module::Refresh, don't do this
    # magic again, or we'll get infinite recursion
    unless (CGI->can('__jifty_real_new')) {
        *CGI::__jifty_real_new = \&CGI::new;

        no warnings qw(redefine);
        *CGI::new = sub {
            return Jifty->handler->cgi if Jifty->handler->cgi;
            CGI::__jifty_real_new(@_);	
        }
    }
};



__PACKAGE__->mk_accessors(qw(dispatcher _view_handlers  cgi apache stash));

=head2 mason


Returns the Jifty c<HTML::Mason> handler. While this "should" be just another template handler,
we still rely on it for little bits of Jifty infrastructure. Patches welcome.

=cut

sub mason {
    my $self = shift;
    return $self->view('Jifty::View::Mason::Handler');
}


=head2 new

Create a new Jifty::Handler object. Generally, Jifty.pm does this only once at startup.

=cut

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;

    $self->create_cache_directories();

    $self->dispatcher( Jifty->app_class( "Dispatcher" ) );
    Jifty::Util->require( $self->dispatcher );
    $self->dispatcher->import_plugins;
	eval { Jifty::Plugin::DumpDispatcher->dump_rules };

    $self->setup_view_handlers();
    return $self;
}


=head2 view_handlers

Returns a list of modules implementing view for your Jifty application.

XXX TODO: this should take pluggable views

=cut


sub view_handlers { qw(Jifty::View::Static::Handler Jifty::View::Declare::Handler Jifty::View::Mason::Handler)}


=head2 fallback_view_handler

Returns the object for our "last-resort" view handler. By default, this is the L<HTML::Mason> handler.

=cut



sub fallback_view_handler { my $self = shift; return $self->view('Jifty::View::Mason::Handler') }

=head2 setup_view_handlers

Initialize all of our view handlers. 


=cut

sub setup_view_handlers {
    my $self = shift;

    $self->_view_handlers({});
    foreach my $class ($self->view_handlers()) {
        $self->_view_handlers->{$class} =  $class->new();
    }

}

=head2 view ClassName


Returns the Jifty view handler for C<ClassName>.

=cut

sub view {
    my $self = shift;
    my $class = shift;
    return $self->_view_handlers->{$class};

}


=head2 create_cache_directories

Attempts to create our app's mason cache directory.

=cut

sub create_cache_directories {
    my $self = shift;

    for ( Jifty->config->framework('Web')->{'DataDir'} ) {
        Jifty::Util->make_path( Jifty::Util->absolute_path($_) );
    }
}


=head2 cgi

Returns the L<CGI> object for the current request, or C<undef> if
there is none.

=head2 apache

Returns the L<HTML::Mason::FakeApache> or L<Apache> object for the
current request, ot C<undef> if there is none.

=head2 handle_request

When your server processs (be it Jifty-internal, FastCGI or anything
else) wants to handle a request coming in from the outside world, you
should call C<handle_request>.

=over

=item cgi

A L<CGI> object that your server has already set up and loaded with
your request's data.

=back

=cut


sub handle_request {
    my $self = shift;
    my %args = (
        cgi => undef,
        @_
    );

    if ( Jifty->config->framework('DevelMode') ) {
        Module::Refresh->refresh;
        Jifty::I18N->refresh;
    }

    Jifty::I18N->get_language_handle;

    $self->cgi( $args{cgi} );
    $self->apache( HTML::Mason::FakeApache->new( cgi => $self->cgi ) );

    # Build a new stash for the life of this request
    $self->stash( {} );
    local $HTML::Mason::Commands::JiftyWeb = Jifty::Web->new();

    Jifty->web->request( Jifty::Request->new()->fill( $self->cgi ) );
    Jifty->web->response( Jifty::Response->new );
    Jifty->api->reset;
    for ( Jifty->plugins ) {
        $_->new_request;
    }
    Jifty->log->debug( "Received request for " . Jifty->web->request->path );
    Jifty->web->setup_session;

    # Return from the continuation if need be
    Jifty->web->request->return_from_continuation;
    Jifty->web->session->set_cookie;
    $self->dispatcher->handle_request();
    $self->cleanup_request();

}

=head2 cleanup_request

Dispatchers should call this at the end of each request, as a class method.
It flushes the session to disk, as well as flushing L<Jifty::DBI>'s cache. 

=cut

sub cleanup_request {
    my $self = shift;
    # Clean out the cache. the performance impact should be marginal.
    # Consistency is improved, too.
    Jifty->web->session->unload();
    Jifty::Record->flush_cache if Jifty::Record->can('flush_cache');
    $self->cgi(undef);
    $self->apache(undef);
    $self->stash(undef);
}

1;
