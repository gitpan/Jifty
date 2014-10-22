use warnings;
use strict;

package Jifty::Script::Server;
use base qw/App::CLI::Command/;

use Jifty::Everything;
use Jifty::Server;
use File::Path ();


=head1 NAME

Jifty::Script::Server - A standalone webserver for your Jifty application

=head1 DESCRIPTION

When you're getting started with Jifty, this is the server you
want. It's lightweight and easy to work with.

=head1 API

=head2 options

The server takes only one option, C<--port>, the port to run the
server on.  This is overrides the port in the config file, if it is
set there.  The default port is 8888.

=cut

sub options {
    (
     'p|port=s' => 'port',
    )
}

=head2 run

C<run> takes no arguments, but starts up a Jifty server process for
you.

=cut

sub run {
    my $self = shift;
    Jifty->new();

    # Purge stale mason cache data
    my $data_dir = Jifty->config->framework('Web')->{'DataDir'};
    if (-d $data_dir) {
        File::Path::rmtree(["$data_dir/cache", "$data_dir/obj"]);
    }

    Jifty::Server->new(port => $self->{port})->run;
}
1;
