use warnings;
use strict;

package Jifty::Plugin::OnlineDocs::Dispatcher;

=head1 NAME

Jifty::Plugin::OnlineDocs::Dispatcher

=head1 DESCRIPTION

Load up the OnlineDocs tab when we're in Admin mode

=cut


use Jifty::Dispatcher -base;
    

on '*' => run {
    if ( Jifty->config->framework('AdminMode') ) {
        my $top = Jifty->web->navigation;
        $top->child(
            OnlineDocs =>
              url      => "/__jifty/online_docs/",
            label      => _('Online docs'),
            sort_order => 999
        );
    }
    return ();
};


1;

