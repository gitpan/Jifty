use warnings;
use strict;

package Jifty::Notification;

use base qw/Jifty::Object Class::Accessor/;
use Email::Send ();
use Email::Simple ();
use Email::Simple::Creator ();

__PACKAGE__->mk_accessors(qw/body preface footer subject from _recipients/);

=head1 USAGE

It is recommended that you subclass L<Jifty::Notification> and
override C<body>, C<subject>, C<recipients>, and C<from> for each
message.  (You may want a base class to provide C<from>, C<preface>
and C<footer> for example.)  This lets you keep all of your
notifications in the same place.

However, if you really want to make a notification type in code
without subclassing, you can create a C<Jifty::Notification> and call
the C<set_body>, C<set_subject>, and so on methods on it.

=head1 METHODS

=cut

=head2 new [KEY1 => VAL1, ...]

Creates a new L<Jifty::Notification>.  Any keyword args given are used
to call set accessors of the same name.

Then it calls C<setup>.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    my %args = @_;

    while (my ($arg, $value) = each %args) {
	if ($self->can($arg)) {
	    $self->$arg($value);
	} else {
	    $self->log->error((ref $self) . " called with invalid argument $arg");
	} 
    } 

    $self->setup;

    return $self;
} 

=head2 setup

Your subclass should override this to set the various field values.

=cut

sub setup {}

=head2 send_one_message

Delivers the notification, using the L<Email::Send> mailer defined in
the C<Mailer> and C<MailerArgs> configuration arguments.  Returns true
if mail was actually sent.  Note errors are not the only cause of mail
not being sent -- for example, the recipients list could be empty.

=cut

sub send_one_message {
    my $self = shift;
    return unless $self->recipients;

    my $message = Email::Simple->create(
        header => [
            From => $self->from,
            To   => (join ', ', $self->recipients),
            Subject => $self->subject,
        ],
        body => join ("\n", $self->preface, $self->body, $self->footer)
    );

    my $method = Jifty->config->framework('Mailer');
    my $args_ref = Jifty->config->framework('MailerArgs');
    $args_ref = [] unless defined $args_ref;

    my $sender = Email::Send->new({mailer => $method, mailer_args => $args_ref });
    
    my $ret = $sender->send($message);

    unless ($ret) {
        $self->log->error("Error sending mail: $ret");
    } 

    $ret;
} 

=head2 body [BODY]

Gets or sets the body of the notification, as a string.

=head2 subject [SUBJECT]

Gets or sets the subject of the notification, as a string.

=head2 from [FROM]

Gets or sets the from address of the notification, as a string.

=head2 recipients [RECIPIENT, ...]

Gets or sets the addresses of the recipients of the notification, as a
list of strings (not a reference).

=cut

__PACKAGE__->mk_accessors(qw/body preface footer subject from _recipients _to_list to/);

sub recipients {
    my $self = shift;
    $self->_recipients([@_]) if @_;
    return @{ $self->_recipients || [] };
} 




=head2 to_list USER, USER, USER

Gets or sets the list of L<BTDT::Model::User>s that the message will
be sent to.  Each user is sent a separate copy of the email.  If
passed no parameters, returns the users that have been set.  This also
suppresses duplicates to users.

=cut

sub to_list {
    my $self = shift;
    if (@_) {
        my %ids = ();
        $ids{$self->to->id} = undef if $self->to;
        $ids{$_->id} = $_ for @_;
        $self->_to_list([grep defined, values %ids]);
    }
    return @{ $self->_to_list || [] };
}

=head2 send

Sends an indivual email to every user in L</to_list>; it does this by
setting L</to> and L</recipient> to the first user in L</to_list>
calling L<Jifty::Notification>'s C<send> method, and progressing down
the list.

Additionally, if L</to> was set elsewhere, sends an email to that
person, as well.

=cut

sub send {
    my $self = shift;

    if ($self->to) {
        $self->recipients($self->to->email);
        $self->send_one_message(@_);
    }
    for my $to ($self->to_list) {
        $self->to($to);
        $self->recipients($to->email);
        $self->send_one_message(@_);
    }
}

=head2 to

Of the list of users that C<to> provided, returns the one which mail
is currently being sent to.  This is set by the L</send> method, such
that it is available to all of the methods that
L<Jifty::Notification>'s C<send> method calls.

=cut

=head2 preface

Print a headerfor the message. You want to override this to print a message.

Returns the message as a scalar.

=cut

sub preface {
    my $self = shift;

    return '';
}


=head2 footer

Print a footer for the message. You want to override this to print a message.

Returns the message as a scalar.

=cut

sub footer {
    return undef;
}


=head2 magic_letme_token_for PATH

Returns a L<Jifty::LetMe> token which allows the current user to access a path on the
site. 

=cut


sub magic_letme_token_for {
    my $self = shift;
    my $path = shift;
    my %args = @_;
    
    my $letme = Jifty::LetMe->new();
    $letme->email($self->to->email);
    $letme->path($path);
    $letme->args(\%args);
    return ($letme->as_url);
}

1;
