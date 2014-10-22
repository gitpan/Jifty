use warnings;
use strict;

package Jifty::Script::Server;
use base qw/Jifty::Script/;

# XXX: if test::builder is not used, sometimes connection is not
# properly closed, causing the client to wait for the content for a
# 302 redirect, see t/06-signup.t, which timeouts after test 24.
# If we load this after we load the rest of Jifty, its die handler clobbers ours.
# HATE.  And even worse, Test::Builder clobbers our global SIG{__DIE__} handler.
# So we work around the work around. The real answer is to figure out how Test::Builder 
# makes our test server not hang and do just that
my $x;
BEGIN {$x = $SIG{__DIE__}; }
use Test::Builder ();
BEGIN { $SIG{__DIE__} = $x;}


use File::Path ();

use constant PIDFILE => 'var/jifty-server.pid';
use constant PARENTPIDFILE => 'var/jifty-server-parent.pid';

=head1 NAME

Jifty::Script::Server - A standalone webserver for your Jifty application

=head1 SYNOPSIS

    jifty server
    jifty server --port 6666
    jifty server --stop

=head1 DESCRIPTION

Starts and stops Jifty's standalone web server.

=head2 options

=over 8

=item --port

The port to run the server on. Overrides the port in the config file, if it is
set there. The default port is 8888.

=item --user USER

The user to become after binding to the port.  It is advised that you
use this when binding to low ports, instead of running as C<root>.
This option only works if the server is using a L<Net::Server>
subclass.

=item --group GROUP

The group to become after binding to the port.  Like C<--user>, this
option only works if the server is using a L<Net::Server> subclass.

=item --host HOSTNAME

The host to bind to.  This option only works if the server is using a
L<Net::Server> subclass.

=item --stop

Stops the server, if it is running.  This is accomplished by reading
the PID from C<var/jifty-server.pid>

=item --restart

restart the server, if it is running. This is accomplished by 
killing the child pid, and let parent pid create a new one

=item --sigready SIGNAL

Sets the signal number that shouldbe sent to the server's parent
process when the server is ready to accept connections.

=item --quiet

Reduces the amount of debug output sent by the server

=item --dbiprof

Turns on DBI profiling; see L<DBI::ProfileDumper>.

=item B<--help>

Print a brief help message and exits.

=item B<--man>

Prints the manual page and exits.

=back

=cut

sub options {
    my $self = shift;
    return (
        $self->SUPER::options,
        'p|port=s'   => 'port',
        'stop'       => 'stop',
        'restart'    => 'restart',
        'sigready=s' => 'sigready',
        'quiet'      => 'quiet',
        'dbiprof'    => 'dbiprof',
        'host=s'     => 'host',
        'u|user=s'   => 'user',
        'g|group=s'  => 'group',
    )
}

=head1 DESCRIPTION

When you're getting started with Jifty, this is the server you
want. It's lightweight and easy to work with.

=head1 METHODS

=head2 run

C<run> takes no arguments, but starts up a Jifty server process for
you.

=cut

sub run {
    my $self = shift;
    if ( $self->{stop} ) {
        $self->_stop;
    }
    elsif ( $self->{restart} ) {
        $self->_stop_child;
    }
    else {
        $self->_fork;
    }
}

sub _fork {
    my $self = shift;
    my $pid = fork;

    die 'fork failed' unless defined $pid;
    if ($pid) {
        open my $fh, '>', PARENTPIDFILE or die "Can't open @{[PARENTPIDFILE]} for writing: $!";
        print $fh $$;
        close $fh;

        wait;
        sleep 1;    # to make cpu happy
        $self->_fork;
    }
    else {
        $self->_run_server;
    }
}

sub _run_server {
    my $self = shift;
    $self->print_help;
    Jifty->new();

    # Purge stale mason cache data
    my $data_dir     = Jifty->config->framework('Web')->{'DataDir'};
    my $server_class = Jifty->config->framework('Web')->{'ServerClass'}
      || 'Jifty::Server';
    die "--user option only available with Net::Server subclasses\n"
      if $self->{user} and $server_class eq "Jifty::Server";
    die "--group option only available with Net::Server subclasses\n"
      if $self->{group} and $server_class eq "Jifty::Server";
    die "--host option only available with Net::Server subclasses\n"
      if $self->{host} and $server_class eq "Jifty::Server";

    Jifty::Util->require($server_class);

    File::Path::rmtree( [ "$data_dir/cache", "$data_dir/obj" ] )
      if Jifty->handler->view('Jifty::View::Mason::Handler')
          and -d $data_dir;

    $SIG{TERM} = sub { exit };
    open my $fh, '>', PIDFILE or die "Can't open @{[PIDFILE]} for writing: $!";
    print $fh $$;
    close $fh;

    Jifty->handle->dbh->{Profile} = '6/DBI::ProfileDumper'
      if $self->{dbiprof};

    $ENV{JIFTY_SERVER_SIGREADY} ||= $self->{sigready}
      if $self->{sigready};
    Log::Log4perl->get_logger($server_class)->less_logging(3)
      if $self->{quiet};
    $Jifty::SERVER = $server_class->new( port => $self->{port} );
    my @args;
    push @args, $_ => $self->{$_}
      for grep { exists $self->{$_} } qw/user group host/;
    $Jifty::SERVER->run(@args);
}

sub _stop {
    my $self = shift;
    open my $fh, '<', PARENTPIDFILE or die "Can't open @{[PARENTPIDFILE]} for reading: $!";
    my $pid = <$fh>;
    kill 'TERM' => $pid;

    $self->_stop_child;
    return;
}

sub _stop_child {
    open my $fh, '<', PIDFILE or die "Can't open @{[PIDFILE]} for reading: $!";
    my $pid = <$fh>;
    kill 'TERM' => $pid;
}

1;
