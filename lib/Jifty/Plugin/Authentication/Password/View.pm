use utf8;
use warnings;
use strict;

=head1 NAME

Jifty::Plugin::Authentication::Password::Login::View

=head1 DESCRIPTION

This code is only useful on the new Jifty "Declarative tempaltes" branch. It shouldn't get in the way 
if you're running a traditional (0.610 or before) Jifty.

=cut

package Jifty::Plugin::Authentication::Password::View;
use HTML::Entities ();
use Jifty::View::Declare -base;

{ no warnings 'redefine';
sub page (&) {
    no strict 'refs'; 
    BEGIN {Jifty::Util->require(Jifty->app_class('View'))};
    &{Jifty->app_class('View') . "::page"}(@_);
}
}


template 'signup' => page {
    title is _('Signup');
    my ( $action, $next ) = get(qw(action next));
    Jifty->web->form->start( call => $next );
    render_param( $action => 'name' , focus => 1);
    render_param( $action => $_ ) for ( grep {$_ ne 'name'} $action->argument_names );
    form_return( label => _('Signup'), submit => $action );
    Jifty->web->form->end();
};

template login => page {
    { title is _('Login!') };
    show('login_widget');
};

template login_widget => sub {

    my ( $action, $next ) = get( 'action', 'next' );
    $action ||= new_action( class => 'Login' );
    $next ||= Jifty::Continuation->new(
        request => Jifty::Request->new( path => "/" ) );
    unless ( Jifty->web->current_user->id ) {
        p {
            outs( _( "No account yet? It's quick and easy. " ));
            tangent( label => _("Sign up for an account!"), url   => '/signup');
        };
        h3  { _('Login with a password') };
        div {
            attr { id => 'jifty-login' };
            Jifty->web->form->start( call => $next );
            render_param( $action, 'email', focus => 1 );
            render_param( $action, $_ ) for (qw(password remember));
            form_return( label => _(q{Login}), submit => $action );
            hyperlink(
                label => _("Lost your password?"),
                url   => "/lost_password"
            );
            Jifty->web->form->end();
        };
    } else {
        outs( _("You're already logged in.") );
    }
};

template 'let/reset_lost_password' => page {
    my ( $next ) = get(qw(next));
    attr { title => 'Reset lost password' };
    my $action = Jifty->web->new_action( class => 'ResetLostPassword' );

    h2   { _('Reset lost password') };
    Jifty->web->form->start( call => $next );
        render_param( $action => $_ ) for ( $action->argument_names );
        form_return( label => _("New password"), submit => $action );
    Jifty->web->form->end();
};

template 'let/confirm_email' => sub {
    new_action( class => 'ConfirmEmail' )->run;
    redirect("/");
};

template 'lost_password' => page {
    my ( $next ) = get(qw(next));
    my $action = Jifty->web->new_action(
        moniker => 'password_reminder',
        class   => 'SendPasswordReminder',
    );

    h2 { _('Send a link to reset your password') };
    outs( _(  "You lost your password. A link to reset it will be sent to the following email address:"));
    my $focused = 0;
    Jifty->web->form->start( call => $next );
        render_param( $action => $_, focus => $focused++ ? 0 : 1 ) for ( $action->argument_names );
            form_return( label => _(q{Send}), submit => $action);
    Jifty->web->form->end;

};

template 'passwordreminder' => page {
    my $next = get('next');
    attr { title => _('Send a password reminder') };
    my $action = Jifty->web->new_action(
        moniker => 'password_reminder',
        class   => 'SendPasswordReminder',
    );
    h2 { _('Send a password reminder') };
    p  { _(  "You lost your password. A reminder will be send to the following mail:") };

    Jifty->web->form->start( call => $next );
        render_param( $action => $_ ) for ( $action->argument_names );
        form_return( label => _("Send"), submit => $action);
    Jifty->web->form->end();
};

1;
