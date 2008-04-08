#!/usr/bin/env perl

use warnings;
use strict;

=head1 DESCRIPTION

If we do a redirect in a 'before' in the dispatcher, actions should
still get run.

=cut

use lib 't/lib';
use Jifty::SubTest;
use Jifty::Test tests => 6;
use Jifty::Test::WWW::Mechanize;

my $server  = Jifty::Test->make_server;

isa_ok($server, 'Jifty::Server');

my $URL     = $server->started_ok;
my $mech    = Jifty::Test::WWW::Mechanize->new();

$mech->get_ok("$URL/say_hi", "Got right page");

$mech->fill_in_action_ok('say_hi', greeting => "something");
ok($mech->click_button(value => "Create"));
$mech->content_contains("dave, something", "Contains right result");

1;
