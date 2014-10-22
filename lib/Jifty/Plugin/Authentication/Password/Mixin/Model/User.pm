use strict;
use warnings;

package Jifty::Plugin::Authentication::Password::Mixin::Model::User;
use Jifty::DBI::Schema;
use base 'Jifty::DBI::Record::Plugin';

use Digest::MD5 qw'';

our @EXPORT = qw(password_is hashed_password_is regenerate_auth_token);

use Jifty::Plugin::Authentication::Password::Record schema {


column auth_token =>
  render_as 'unrendered',
  type is 'varchar',
  default is '',
  label is _('Authentication token');
    


column password =>
  is mandatory,
  is unreadable,
  label is _('Password'),
  type is 'varchar',
  hints is _('Your password should be at least six characters'),
  render_as 'password',
  filters are 'Jifty::DBI::Filter::SaltHash';


};

sub register_triggers {
    my $self = shift;
    $self->add_trigger(name => 'after_create', callback => \&after_create);
    $self->add_trigger(name => 'after_set_password', callback => \&after_set_password);
    $self->add_trigger(name => 'validate_password', callback => \&validate_password, abortable =>1);
}


=head2 password_is PASSWORD

Checks if the user's password matches the provided I<PASSWORD>.

=cut

sub password_is {
    my $self = shift;
    my $pass = shift;

    return undef unless $self->_value('password');
    my ($hash, $salt) = @{$self->_value('password')};

    return 1 if ( $hash eq Digest::MD5::md5_hex($pass . $salt) );
    return undef;

}

=head2 hashed_password_is HASH TOKEN

Check if the given I<HASH> is the result of hashing our (already
salted and hashed) password with I<TOKEN>

=cut

sub hashed_password_is {
    my $self = shift;
    my $hash = shift;
    my $token = shift;

    my $password = $self->_value('password');
    return $password && Digest::MD5::md5_hex("$token " . $password->[0]) eq $hash;
}


=head2 validate_password

Makes sure that the password is six characters long or longer.

=cut

sub validate_password {
    my $self      = shift;
    my $new_value = shift;

    return ( 0, _('Passwords need to be at least six characters long') )
        if length($new_value) < 6;

    return 1;
}


sub after_create {
    my $self = shift;
    # We get a reference to the return value of insert
    my $value = shift; return unless $$value; $self->load($$value);
    $self->regenerate_auth_token;
    if ( $self->id and $self->email and not $self->email_confirmed ) {
        Jifty->app_class('Notification','ConfirmEmail')->new( to => $self )->send;
    } else {
        warn  $self->id . " " .$self->email;
    }


}

=head2 after_set_password

Regenerate auth tokens on password change

=cut

sub after_set_password {
    my $self = shift;
    $self->regenerate_auth_token;
}

=head2 regenerate_auth_token

Generate a new auth_token for this user. This will invalidate any
existing feed URLs.

=cut

sub regenerate_auth_token {
    my $self = shift;
    my $auth_token = '';

    $auth_token .= unpack('H2', chr(int rand(256))) for (1..16);

    $self->__set(column => 'auth_token', value => $auth_token);
}



1;

