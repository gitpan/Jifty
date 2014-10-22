#!/usr/bin/perl

use warnings;
use strict;

=head1 DESCRIPTION

Continuations tests

=cut

BEGIN {chdir "t/Mapper"}
use lib '../../lib';
use Jifty::Test no_plan => 1;

use_ok('Jifty::Test::WWW::Mechanize');

# Set up server
my $server = Jifty::Test->make_server;
my $URL = $server->started_ok;
my $mech = Jifty::Test::WWW::Mechanize->new;

# Check that the first page is as we expect it
$mech->get("$URL/");
$mech->content_like(qr/Get the holy grail/, "Start page has expected content");
$mech->content_unlike(qr/got the grail/, "Start page doesn't have output of run action");

# ..and that the action does what we think it does
$mech->get("$URL/index.html?J:A-grail=GetGrail");
$mech->content_like(qr/got the grail/, "Running the action produces the expected result");



1;

