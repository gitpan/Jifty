# This test is for testing Jifty.update() javascript function.

use strict;
use warnings;
use Jifty::Test::Dist qw(no_plan);
use Jifty::Test::WWW::Selenium;
use utf8;

my $server = Jifty::Test->make_server;
my $sel    = Jifty::Test::WWW::Selenium->rc_ok($server);
my $URL    = $server->started_ok;

for my $test_file (qw(01.behaviour.html 02.action.html)) {
    $sel->open_ok("/static/js-test/$test_file");
    my $html = $sel->get_text("test");
    $html =~ /(\d+)\.\.(\d+)/;

    for($1..$2) {
        $sel->wait_for_text_present("exact:ok $_");
        ok(! $sel->is_text_present("exact:nok $_") );
    }
}

$sel->stop;

