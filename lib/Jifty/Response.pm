use warnings;
use strict;

package Jifty::Response;

=head1 NAME

Jifty::Response - Canonical internal representation of the result of a L<Jifty::Action>

=head1 DESCRIPTION

The answer to a L<Jifty::Request> is a C<Jifty::Response> object.
Currently, the response object exists merely to collect the
L<Jifty::Result> objects of each L<Jifty::Action> that ran.

=cut

use base qw/Jifty::Object Class::Accessor::Fast/;

__PACKAGE__->mk_accessors(qw(error));

=head2 new

Creates a new L<Jifty::Response> object.

=cut

sub new {
    my $class = shift;
    bless {results => {}, headers => []}, $class;
}


=head2 add_header KEY => VALUE

Add an HTTP header to the outgoing HTTP response. 

=cut


sub add_header {
    my $self = shift;
     Jifty->handler->apache->header_out( @_ ) if Jifty->handler->apache;

    # This one is so we can get jifty's headers into mason
    # Otherwise we'd have to wrap mason's output layer

    push @{$self->{headers}}, [@_];
}

=head2 headers

Returns an array of key-value pairs of all the HTTP headers we want to
stick on the outgoing HTTP request.


=cut

sub headers {
    my $self = shift;
    return @{$self->{headers}};
}

=head2 result MONIKER [RESULT]

Gets or sets the L<Jifty::Result> of the L<Jifty::Action> with the given
I<MONIKER>.

=cut

sub result {
    my $self = shift;
    my $moniker = shift;
    $self->{results}{$moniker} = shift if @_;
    return $self->{results}{$moniker};
}

=head2 results

Returns a hash which maps moniker to its L<Jifty::Result>

=cut

sub results {
    my $self = shift;
    return %{$self->{results}};
}

=head2 messages

Returns the aggregate messages of all of the L<Jifty::Result>s.

=cut

sub messages {
    my $self = shift;
    my %results = $self->results;
    return map {$_, $results{$_}->message} grep {defined $results{$_}->message and length $results{$_}->message} sort keys %results;
}

=head2 error [MESSAGE]

Gets or sets a generalized error response.  Setting an error also
makes the response a L</failure>.

=head2 success

Returns true if none of the results are failures and there is no
L</error> set.

=cut

sub success {
    my $self = shift;
    return 0 if grep {$_->failure} values %{$self->{results}};
    return 1;
}

=head2 failure

Returns true if any of the results failed or there was an L</error>
set.

=cut

sub failure {
    my $self = shift;
    return not $self->success;
}

1;
