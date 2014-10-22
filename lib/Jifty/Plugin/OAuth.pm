package Jifty::Plugin::OAuth;
use strict;
use warnings;

use base qw/Jifty::Plugin/;

our $VERSION = 0.01;

=head1 NAME

Jifty::Plugin::OAuth

=head1 DESCRIPTION

A OAuth web services API for your Jifty app.

=head1 WARNING

This plugin is not yet complete. DO NOT USE IT.

=head1 USAGE

Add the following to your site_config.yml

 framework:
   Plugins:
     - OAuth: {}

=head1 GLOSSARY

=over 4

=item service provider

A service provider is an application that has users who have private data. This
plugin enables your Jifty application to be an OAuth service provider.

=item consumer

A consumer is an application that wants to access users' private data. The
service provider (in this case, this plugin) ensures that this happens securely
and with users' full approval. Without OAuth (or similar systems), this would
be accomplished perhaps by the user giving the consumer her login information.
Obviously not ideal.

This plugin does not yet implement the consumer half of the protocol.

=item request token

A request token is a unique, random string that a user may authorize for a
consumer.

=item access token

An access token is a unique, random string that a consumer can use to access
private resources on the authorizing user's behalf. Consumers may only
receive an access token if they have an authorized request token.

=back

=head1 NOTES

You must provide public access to C</oauth/request_token> and
C</oauth/access_token>.

You must not allow public access to C</oauth/authorize>. C</oauth/authorize>
depends on having the user be logged in.

There is currently no way for consumers to add themselves. This might change in
the future, but it would be a nondefault configuration. Consumers must
contact you and provide you with the following data:

=over 4

=item consumer_key

An arbitrary string that uniquely identifies a consumer. Preferably something
random over, say, "Hiveminder".

=item secret

A (preferably random) string that is used to ensure that it's really the
consumer you're talking to. After the consumer provides this to you, it's never
sent in plaintext. It is always, however, included in cryptographic signatures.

=item name

A readable name to use in displaying the consumer to users. This is where you'd
put "Hiveminder".

=item url (optional)

The website of the consumer.

=item rsa_key (optional)

The consumer's public RSA key. This is optional. Without it, they will not be
able to use the RSA-SHA1 signature method. They can still use HMAC-SHA1 though.

=back

=head1 TECHNICAL DETAILS

OAuth is an open protocol that enables consumers to access users' private data
in a secure and authorized manner. The way it works is:

=over 4

=item

The consumer establishes a key and a secret with the service provider. This
step only happens once.

=item

The user is using the consumer's application and decides that she wants to
use some data that she already has on the service provider's application.

=item

The consumer asks the service provider for a request token. The service
provider generates one and gives it to the consumer.

=item

The consumer directs the user to the service provider with that request token.

=item

The user logs in and authorizes that request token.

=item

The service provider directs the user back to the consumer.

=item

The consumer asks the service provider to exchange his authorized request token
for an access token. This access token lets the consumer access resources on
the user's behalf in a limited way, for a limited amount of time.

=back

By establishing secrets and using signatures and timestamps, this can be done
in a very secure manner. For example, a replay attack (an eavesdropper repeats
a request made by a legitimate consumer) is actively defended against.

=head1 SEE ALSO

L<Net::OAuth::Request>, L<http://oauth.net/>

=head1 AUTHOR

Shawn M Moore C<< <sartak@bestpractical.com> >>

=cut

1;
