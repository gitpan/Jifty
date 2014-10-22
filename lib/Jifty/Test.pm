use warnings;
use strict;

package Jifty::Test;
use base qw/Test::More/;

use Jifty::Util;
use Email::LocalDelivery;
use Email::Folder;
use File::Path;
use File::Spec;
use File::Temp;
use Hash::Merge;
use Digest::MD5 qw/md5_hex/;
use Cwd qw/abs_path cwd/;

=head1 NAME

Jifty::Test - Jifty's test module

=head1 SYNOPSIS

    use Jifty::Test tests => 5;

    # ...all of Test::More's functionality...
    my $model = MyApp::Model::MyModel->new;
    $model->create();
    ok($model->id, 'model works');
    is($model->foo, 'some default', 'default works');

    # Startup an external server (see Jifty::TestServer)
    my $server = Jifty::Test->make_server;
    my $server_url = $server->started_ok;
    # You're probably also interested in Jifty::Test::WWW::Mechanize

=head1 DESCRIPTION

Jifty::Test is a superset of L<Test::More>.  It provides all of
Test::More's functionality in addition to the class methods defined
below.

=head1 METHODS

=head2 is_passing

    my $is_passing = Jifty::Test->is_passing;

Check if the test is currently in a passing state.

=over

=item * 

All tests run so far have passed

=item * 

We have run at least one test

=item * 

We have not run more than we planned (if we planned at all)

=back

=cut

sub is_passing {
    my $tb = Jifty::Test->builder;

    my $is_failing = grep {not $_} $tb->summary;
    no warnings 'uninitialized';
    $is_failing ||= $tb->has_plan eq 'no_plan'
                      ? 0
                      : $tb->expected_tests < $tb->current_test;

    return !$is_failing;
}


=head2 is_done

    my $is_done = Jifty::Test->is_done;

Check if we have run all the tests we've planned.

If the plan is 'no_plan' then is_done() will return true if at least
one test has run.

=cut

sub is_done {
    my $tb = Jifty::Test->builder;

    no warnings 'uninitialized';
    if( $tb->has_plan eq 'no_plan' ) {
        return $tb->current_test > 0;
    }
    else {
        return $tb->expected_tests == $tb->current_test;
    }
}


=begin private

=head2 import_extra

Called by L<Test::More>'s C<import> code when L<Jifty::Test> is first
C<use>'d, it calls L</setup>, and asks Test::More to export its
symbols to the namespace that C<use>'d this one.

=end private

=cut

sub import_extra {
    my $class = shift;
    my $args  = shift;

    $class->setup($args);
    Test::More->export_to_level(2);

    # Now, clobber Test::Builder::plan (if we got given a plan) so we
    # don't try to spit one out *again* later
    if ($class->builder->has_plan) {
        no warnings 'redefine';
        *Test::Builder::plan = sub {};
    }
}

=head2 setup ARGS

This method is passed a single argument. This is a reference to the array of parameters passed in to the import statement.

Merges the L</test_config> into the default configuration, resets the
database, and resets the fake "outgoing mail" folder.  

This is the method to override if you wish to do custom setup work, such as
insert test data into your database.

  package MyApp::Test;
  use base qw/ Jifty::Test /;

  sub setup {
      my $self = shift;
      my $args = shift;

      # Make sure to call the super-class version
      $self->SUPER::setup($args);

      # Now that we have the database and such...
      my %test_args = @$args;

      if ($test_arg{something_special}) {
          # do something special...
      }
  }

And later in your tests, you may do the following:

  use MyApp::Test tests => 14, something_special => 1;

  # 14 tests with some special setup...

=cut

sub setup {
    my $class = shift;
    my $args = shift;

    # Spit out a plan (if we got one) *before* we load modules, in
    # case of compilation errors
    $class->builder->plan(@{$args})
      unless $class->builder->has_plan;

    # Require the things we need
    require Jifty::YAML;
    require Jifty::Server;
    require Jifty::Script::Schema;

    my $test_config = File::Temp->new( UNLINK => 0 );
    Jifty::YAML::DumpFile("$test_config", $class->test_config(Jifty::Config->new));
    # Invoking bin/jifty and friends will now have the test config ready.
    $ENV{'JIFTY_TEST_CONFIG'} ||= "$test_config";
    $class->builder->{test_config} = $test_config;
    {
        # Cache::Memcached stores things. And doesn't let them expire
        # from the cache easily. This is fine in production, but
        # during testing each test script needs its own namespace.  we
        # use the pid of the current process, and save it so the keys
        # stays the same when we fork
      {
          package Jifty::Record;
          no warnings qw/redefine/;

          use vars qw/$cache_key_prefix/;

          $cache_key_prefix = "jifty-test-" . $$;
          
          *Jifty::Record::cache_key_prefix = sub {
              $Jifty::Record::cache_key_prefix;
          }
      }
        
    }
    my $root = Jifty::Util->app_root;

    # Mason's disk caching sometimes causes false tests
    rmtree([ File::Spec->canonpath("$root/var/mason") ], 0, 1);

    $class->setup_test_database;

    $class->setup_mailbox;
}

=head2 setup_test_database

Create the test database. This can be overloaded if you do your databases in a
different way.

=cut

sub setup_test_database {
    my $class = shift;


    if ($ENV{JIFTY_FAST_TEST}) {
	local $SIG{__WARN__} = sub {};
	eval { Jifty->new( no_version_check => 1 ); Jifty->handle->check_schema_version };
	my $booted;
	if (Jifty->handle && !$@) {
	    my $baseclass = Jifty->app_class;
	    for my $model_class ( grep {/^\Q$baseclass\E::Model::/} Jifty::Schema->new->models ) {
		# We don't want to get the Collections, for example.
		next unless $model_class->isa('Jifty::DBI::Record');
		Jifty->handle->simple_query('TRUNCATE '.$model_class->table );
		Jifty->handle->simple_query('ALTER SEQUENCE '.$model_class->table.'_id_seq RESTART 1');
	    }
	    # Load initial data
	    eval {
		my $bootstrapper = Jifty->app_class("Bootstrap");
		Jifty::Util->require($bootstrapper);
		$bootstrapper->run() if $bootstrapper->can('run');
	    };
	    die $@ if $@;
	    $booted = 1;
	}
	if (Jifty->handle) {
	    Jifty->handle->disconnect;
	    Jifty->handle(undef);
	}
	if ($booted) {
            Jifty->new();
	    return;
	}
    }

    Jifty->new( no_handle => 1, pre_init => 1 );

    my $schema = Jifty::Script::Schema->new; $schema->{drop_database}     = 1;
    $schema->{create_database}   = 1;
    $schema->{create_all_tables} = 1;
    $schema->run;

    Jifty->new();
}

=head2 load_test_configs FILENAME

This will load all the test config files that apply to FILENAME (default:
C<$0>, the current test script file). Say you are running the test script
C</home/bob/MyApp/t/user/12-delete.t>. The files that will be loaded are:

=over 4

=item C</home/bob/MyApp/t/user/12-delete.t-config.yml>

=item C</home/bob/MyApp/t/user/test_config.yml>

=item C</home/bob/MyApp/t/test_config.yml>

=back

..followed by the usual Jifty configuration files (such as
C<MyApp/etc/config.yml> and C<MyApp/etc/site_config.yml>). The options in a
more specific test file override the options in a less specific test file.

The options are returned in a single hashref.

=cut

sub load_test_configs {
    my $class = shift;
    my ($test_config_file) = @_;

    # Jifty::SubTest uses chdir which screws up $0, so to be nice it also makes
    # available the cwd was before it uses chdir.
    my $cwd = $Jifty::SubTest::OrigCwd;

    # get the initial test config file, which is the input . "-config.yml"
    $test_config_file = $0 if !defined($test_config_file);
    $test_config_file .= "-config.yml";
    $test_config_file = File::Spec->rel2abs($test_config_file, $cwd);

    my $test_options = _read_and_merge_config_file($test_config_file, {});

    # get the directory of the input, so we can recurse upwards
    my ($volume, $directories) = File::Spec->splitpath($test_config_file);
    my $directory = File::Spec->catdir($volume, $directories);

    my $depth = $ENV{JIFTY_TEST_DEPTH} || 30;

    for (1 .. $depth)
    {
        my $file = File::Spec->catfile($directory, "test_config.yml");
        $test_options = _read_and_merge_config_file($file, $test_options);

        # are we at the app root? if so, then we can stop moving up
        $directory = abs_path(File::Spec->catdir($directory, File::Spec->updir($directory)));
        return $test_options
            if Jifty::Util->is_app_root($directory);
    }

    Jifty->log->fatal("Stopping looking for test config files after recursing upwards $depth times. Either you have a nonstandard layout or an incredibly deep test hierarchy. If you really do have an incredibly deep test hierarchy, you can set the environment variable JIFTY_TEST_DEPTH to a larger value.");

    return $test_options;
}

sub _read_and_merge_config_file {
    my $file = shift;
    my $config = shift;

    my $file_options = Jifty::Config->load_file($file);

    Hash::Merge::set_behavior('RIGHT_PRECEDENT');

    # merge the new options into what we have so far
    return Hash::Merge::merge($file_options, $config);
}

=head2 test_config

Returns a hash which overrides parts of the application's
configuration for testing.  By default, this changes the database name
by appending a 'test', as well as setting the port to a random port
between 10000 and 15000. Individual test configurations may override these
defaults (see C<load_test_configs>).

It is passed the current configuration before any test config is loaded.

You can override this to provide application-specific test
configuration, e.g:

    sub test_config {
        my $class = shift;
        my ($config) = @_;
        my $hash = $class->SUPER::test_config($config);
        $hash->{framework}{LogConfig} = "etc/log-test.conf"
    
        return $hash;
    }

Note that this is deprecated in favor of having real config files in your
test directory.

=cut

sub test_config {
    my $class = shift;
    my ($config) = @_;

    my $defaults = {
        framework => {
            Database => {
                Database => $config->framework('Database')->{Database} . $class->_testfile_to_dbname(),
            },
            Web => {
                Port => int(rand(5000) + 10000),
                DataDir => File::Temp::tempdir('masonXXXXXXXXXX', CLEANUP => 1)
            },
            Mailer => 'Jifty::Test',
            MailerArgs => [],
            LogLevel => 'WARN',
            TestMode => 1,
        }
    };

    Hash::Merge::set_behavior('RIGHT_PRECEDENT');
    return Hash::Merge::merge($defaults, $class->load_test_configs);
}


sub _testfile_to_dbname {
    return 'fasttest' if $ENV{JIFTY_FAST_TEST};
    my $dbname = lc($0);
    $dbname =~ s/\.t$//;
    $dbname =~ s/(\W|[_-])+//g;
    $dbname .= substr(md5_hex(cwd()), 0, 8);
    $dbname = substr($dbname,-32,32);
    return $dbname;
}

=head2 make_server

Creates a new L<Jifty::Server> which C<ISA> L<Jifty::TestServer> and
returns it.

=cut

sub make_server {
    my $class = shift;

    # XXX: Jifty::TestServer is not a Jifty::Server, it is actually
    # server controller that invokes bin/jifty server. kill the
    # unshift here once we fix all the tests expecting it to be
    # jifty::server.
    if ($ENV{JIFTY_TESTSERVER_PROFILE} ||
        $ENV{JIFTY_TESTSERVER_COVERAGE} ||
        $ENV{JIFTY_TESTSERVER_DBIPROF} ||
        $^O eq 'MSWin32') {
        require Jifty::TestServer;
        unshift @Jifty::Server::ISA, 'Jifty::TestServer';
    } elsif ($ENV{JIFTY_APACHETEST}) {
        require Jifty::TestServer::Apache;
        unshift @Jifty::Server::ISA, 'Jifty::TestServer::Apache';
    }
    else {
        require Test::HTTP::Server::Simple;
        unshift @Jifty::Server::ISA, 'Test::HTTP::Server::Simple';
    }

    my $server = Jifty::Server->new;

    return $server;
}


=head2 web

Like calling C<<Jifty->web>>.

C<<Jifty::Test->web>> does the necessary Jifty->web initialization for
it to be usable in a test.

=cut

sub web {
    my $class = shift;

    Jifty->web->request(Jifty::Request->new)   unless Jifty->web->request;
    Jifty->web->response(Jifty::Response->new) unless Jifty->web->response;

    return Jifty->web;
}


=head2 mailbox

A mailbox used for testing mail sending.

=cut

sub mailbox {
    return Jifty::Util->absolute_path("t/mailbox_" . _testfile_to_dbname());
}

=head2 setup_mailbox

Clears the mailbox.

=cut

sub setup_mailbox {
    my $class = shift;

    open my $f, ">:encoding(UTF-8)", $class->mailbox;
    close $f;
}

=head2 teardown_mailbox

Deletes the mailbox.

=cut

sub teardown_mailbox {
    unlink mailbox();
}

=head2 is_available

Informs L<Email::Send> that L<Jifty::Test> is always available as a mailer.

=cut

sub is_available { 1 }

=head2 send

Should not be called manually, but is
automatically called by L<Email::Send> when using L<Jifty::Test> as a mailer.

(Note that it is a class method.)

=cut

sub send {
    my $class = shift;
    my $message = shift;

    Email::LocalDelivery->deliver($message->as_string, mailbox());
}

=head2 messages

Returns the messages in the test mailbox, as a list of
L<Email::Simple> objects.  You may have to use a module like
L<Email::MIME> to parse multi-part messages stored in the mailbox.

=cut

sub messages {
    return Email::Folder->new(mailbox())->messages;
}


=head2 test_file

  my $files = Jifty::Test->test_file($file);

Register $file as having been created by the test.  It will be
cleaned up at the end of the test run I<if and only if> the test
passes.  Otherwise it will be left alone.

It returns $file so you can do this:

  my $file = Jifty::Test->test_file( Jifty::Util->absolute_path("t/foo") );

=cut

my @Test_Files_To_Cleanup;
sub test_file {
    my $class = shift;
    my $file = shift;

    push @Test_Files_To_Cleanup, $file;

    return $file;
}


=head2 test_in_isolation

  my $return = Jifty::Test->test_in_isolation( sub {
      ...your testing code...
  });

For testing testing modules so you can run testing code (which perhaps
fail) without effecting the outer test.

Saves the state of Jifty::Test's Test::Builder object and redirects
all output to dev null before running your testing code.  It then
restores the Test::Builder object back to its original state.

    # Test that fail() returns 0
    ok !Jifty::Test->test_in_isolation sub {
        return fail;
    };

=cut

sub test_in_isolation {
    my $class = shift;
    my $code  = shift;

    my $tb = Jifty::Test->builder;

    my $output         = $tb->output;
    my $failure_output = $tb->failure_output;
    my $todo_output    = $tb->todo_output;
    my $current_test   = $tb->current_test;

    $tb->output( File::Spec->devnull );
    $tb->failure_output( File::Spec->devnull );
    $tb->todo_output( File::Spec->devnull );

    my $result = $code->();

    $tb->output($output);
    $tb->failure_output($failure_output);
    $tb->todo_output($todo_output);
    $tb->current_test($current_test);

    return $result;
}


# Stick the END block in a method so we can test it.
END { Jifty::Test->_ending }

sub _ending {
    my $Test = Jifty::Test->builder;
    # Such a hack -- try to detect if this is a forked copy and don't
    # do cleanup in that case.
    return if $Test->{Original_Pid} != $$;

    # If all tests passed..
    if (Jifty::Test->is_passing && Jifty::Test->is_done) {
        # Clean up mailbox
        Jifty::Test->teardown_mailbox;

        # Disconnect the PubSub bus, if need be; otherwise we may not
        # be able to drop the testing database
        Jifty->bus->disconnect
          if Jifty->config and Jifty->bus;

        # Remove testing db
        if (Jifty->handle && !$ENV{JIFTY_FAST_TEST}) {
            Jifty->handle->disconnect();
            my $schema = Jifty::Script::Schema->new;
            $schema->{drop_database} = 1;
            $schema->run;
        }

        # Unlink test files
        unlink @Test_Files_To_Cleanup;
    }

    # Cleanup the tempdirs
    File::Temp::cleanup();

    # Unlink test file
    unlink $Test->{test_config} if $Test->{test_config};
}

=head1 SEE ALSO

L<Jifty::Test::WWW::Mechanize>, L<Jifty::TestServer>

=cut

1;
