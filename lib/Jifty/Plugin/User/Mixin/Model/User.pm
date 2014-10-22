use strict;
use warnings;

package Jifty::Plugin::User::Mixin::Model::User;
use Jifty::DBI::Schema;


=head1 NAME

Jifty::Plugin::User::Mixin::Model::User

=head1 DESCRIPTION

 package MyApp::Model::User;
 use Jifty::DBI::Schema;
 use MyApp::Record schema { 
     # column definitions
 };
 
 use Jifty::Plugin::User::Mixin::Model::User; # Imports two columns: name and email
 

=cut

use base 'Jifty::DBI::Record::Plugin';
use Jifty::Plugin::User::Record schema {
    column
        name => type is 'text',
        label is _('Nickname'),
        hints is _('How should I display your name to other users?');
    column
        email => type is 'text',
        label is _('Email address'), default is '', is immutable, is distinct;
    column
        email_confirmed => label is _('Email address confirmed?'),
        type is 'boolean';

};

# Your model-specific methods go here.



=head2 set_email ADDRESS

Whenever a user's email is set to a new value, we need to make 
sure they reconfirm it.

=cut

{
    no warnings 'redefine';

sub set_email {
    my $self  = shift;
    my $new_address = shift;
    my $email = $self->__value('email');

    my @ret = $self->_set( column => 'email', value => $new_address);

    unless ( $email eq $self->__value('email') ) {
        $self->__set( column => 'email_confirmed', value => '0' );
        Jifty->app_class('Notification','ConfirmEmail')->new( to => $self )->send;
    }

    return (@ret);
}

}

=head2 validate_email

Makes sure that the email address looks like an email address and is
not taken.

=cut

sub validate_email {
    my $self      = shift;
    my $new_email = shift;
    
    return ( 0, _("That %1 doesn't look like an email address.", $new_email) )
        if $new_email !~ /\S\@\S/;
    
    my $temp_user = Jifty->app_class('Model','User')->new( current_user => Jifty->app_class('CurrentUser')->superuser );
    $temp_user->load_by_cols( 'email' => $new_email );
    
    # It's ok if *we* have the address we're looking for
    return ( 0, _('It looks like somebody else is using that address. Is there a chance you have another account?') )
        if $temp_user->id && ( !$self->id || $temp_user->id != $self->id );
    
    return 1;
}


1;

