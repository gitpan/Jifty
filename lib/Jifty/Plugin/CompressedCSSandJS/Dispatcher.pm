use warnings;
use strict;

package Jifty::Plugin::CompressedCSSandJS::Dispatcher;

=head1 NAME

Jifty::Plugin::CompressedCSSandJS::Dispatcher

=head1 DESCRIPTION

Adds dispatcher rules for C</__jifty/js/*> and C</__jifty/css/*/>,
which serve out compiled and compressed CSS and Javascript rules.

=cut
use HTTP::Date ();

use Jifty::Dispatcher -base;


on '/__jifty/js/*' => run {
    my $arg = $1;
    if ( $arg !~ /^[0-9a-f]{32}\.js$/ ) {

        # This doesn't look like a real request for squished JS,
        # so redirect to a more failsafe place
        Jifty->web->redirect( "/static/js/" . $arg );
    }

    my ($ccjs) = Jifty->find_plugin('Jifty::Plugin::CompressedCSSandJS')
        or Jifty->web->redirect( "/static/js/" . $arg );

    $ccjs->_generate_javascript;

    $arg =~ s/\.js$//;
    $ccjs->_serve_cas_object( 'js-all', $arg );
    abort;
};

on '/__jifty/css/*' => run {
    my $arg = $1;
    my ($ccjs) = Jifty->find_plugin('Jifty::Plugin::CompressedCSSandJS');
    if ( $arg !~ /^[0-9a-f]{32}\.css$/ || !$ccjs) {

        # This doesn't look like a real request for squished CSS,
        # so redirect to a more failsafe place
        Jifty->web->redirect( "/static/css/" . $arg );
    }

    $ccjs->generate_css;

    $arg =~ s/\.css$//;
    $ccjs->_serve_cas_object( 'css-all', $arg );
    abort;
};

1;
