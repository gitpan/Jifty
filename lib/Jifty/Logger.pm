use warnings;
use strict;

package Jifty::Logger;

=head1 NAME

Jifty::Logger -- A master class for Jifty's logging framwork

=head1 DESCRIPTION

Jifty uses the Log4perl module to log error messages. In Jifty
programs there's two ways you can get something logged:

Firstly, Jifty::Logger captures all standard warnings that Perl
emmits.  So in addtion to everying output from perl via the 
warnings pragmas, you can also log messages like so:

    warn("The WHAM is overheating!");

This doesn't give you much control however.  The second way
allows you to specify the level that you want logging to
occur at:

    Jifty->log->debug("Checking the WHAM");
    Jifty->log->info("Potential WHAM problem detected");
    Jifty->log->warn("The WHAM is overheating");
    Jifty->log->error("PANIC!");
    Jifty->log->fatal("Someone call Eddie Murphy!");

=head2 Configuring Log4perl

Unless you specify otherwise in the configuration file, Jifty will
supply a default Log4perl configuration.

The default log configuration that logs all messages to the screen
(i.e. to STDERR, be that directly to the terminal or to fastcgi's
log file.)  It will log all messages of equal or higher priority
to he LogLevel configuration option.

    --- 
    framework: 
      LogLevel: DEBUG

You can tell Jifty to use an entirely different Logging
configuration by specifying the filename of a standard Log4perl
config file in the LogConfig config option (see L<Log::Log4perl> for
the format of this config file.)

    --- 
    framework: 
      LogConfig: etc/log4perl.conf

Note that specifying your own config file prevents the LogLevel
config option from having any effect.

You can tell Log4perl to check that file perodically for changes.
This costs you a little in application performance, but allows
you to change the logging level of a running application.  You
need to set LogReload to the frequency, in seconds, that the
file should be checked.

    --- 
    framework: 
      LogConfig: etc/log4perl.conf
      LogReload: 10

(This is implemented with Log4perl's init_and_watch functionality)

=cut

use Log::Log4perl;

use base qw/Jifty::Object/;

=head1 METHODS

=head2 new COMPONENT

This class method instantiates a new C<Jifty::Logger> object. This
object deals with logging for the system.

Takes an optional name for this Jifty's logging "component" - See
L<Log::Log4perl> for some detail about what that is.  It sets up a "warn"
handler which logs warnings to the specified component.

=cut

sub new {
    my $class     = shift;
    my $component = shift;

    my $self = {};
    bless $self, $class;

    $component = '' unless defined $component;

    # configure Log::Log4perl unless we've done it already
    if (not Log::Log4perl->initialized) {
       $class->_initialize_log4perl;
    }
    
    # create a log4perl object that answers to this component name
    my $logger = Log::Log4perl->get_logger($component);
    
    # whenever Perl wants to warn something out capture it with a signal
    # handler and pass it to log4perl
    $SIG{__WARN__} = sub {

        # This caller_depth line tells Log4perl to report
        # the error as coming from on step further up the
        # caller chain (ie, where the warning originated)
        # instead of from the $logger->warn line.
        local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;

        # If the logger has been taken apart by global destruction,
        # don't try to use it to log warnings
        if (Log::Log4perl->initialized) {
            # @_ often has read-only scalars, so we need to break
            # the aliasing so we can remove trailing newlines
            my @lines = map {"$_"} @_;
            $logger->warn(map {chomp; $_} @lines);
        }
    };

    return $self;
}

sub _initialize_log4perl {
    my $class = shift;
  
    my $log_config
        = Jifty::Util->absolute_path( Jifty->config->framework('LogConfig') );

    if ( defined Jifty->config->framework('LogReload') ) {
        Log::Log4perl->init_and_watch( $log_config,
            Jifty->config->framework('LogReload') );
    } elsif ( -f $log_config and -r $log_config ) {
        Log::Log4perl->init($log_config);
    } else {
        my $log_level = uc Jifty->config->framework('LogLevel');
        my %default = (
            'log4perl.rootLogger'        => "$log_level,Screen",
            '#log4perl.logger.SchemaTool' => "$log_level,Screen",
            'log4perl.appender.Screen'   => 'Log::Log4perl::Appender::Screen',
            'log4perl.appender.Screen.stderr' => 1,
            'log4perl.appender.Screen.layout' =>
                'Log::Log4perl::Layout::SimpleLayout'
        );
        Log::Log4perl->init( \%default );
  }
}

=head1 AUTHOR

Various folks at Best Practical Solutions, LLC.

Mark Fowler <mark@twoshortplanks.com> fiddled a bit.

=cut

1;
