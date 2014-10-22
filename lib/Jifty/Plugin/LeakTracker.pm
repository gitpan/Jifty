use strict;
use warnings;

package Jifty::Plugin::LeakTracker;
use base qw/Jifty::Plugin Class::Data::Inheritable/;
use Data::Dumper;
use Devel::Events::Handler::ObjectTracker;
use Devel::Events::Generator::Objects;
use Devel::Size 'total_size';

our $VERSION = 0.01;

__PACKAGE__->mk_accessors(qw(tracker generator));
our @requests;

my $empty_array = total_size([]);

=head2 init

init installs the triggers needed around each HTTP request
=cut

sub init {
    my $self = shift;
    return if $self->_pre_init;

    Jifty::Handler->add_trigger(
        before_request => sub { $self->before_request(@_) }
    );

    Jifty::Handler->add_trigger(
        after_request  => sub { $self->after_request(@_) }
    );
}

=head2 before_request

This trigger sets up Devel::Events to instrument bless and free so it can keep
track of all the objects created and destroyed in this request

=cut

sub before_request
{
    my $self = shift;
    $self->tracker(Devel::Events::Handler::ObjectTracker->new());
    $self->generator(
        Devel::Events::Generator::Objects->new(handler => $self->tracker)
    );

    $self->generator->enable();
}

=head2 after_request

This extracts all the data gathered by Devel::Events and puts it into the
global C<@Jifty::Plugin::LeakTracker::requests> so the LeakTracker dispatcher
and views can query it to make nice reports

=cut

sub after_request
{
    my $self = shift;
    my $handler = shift;
    my $cgi = shift;

    $self->generator->disable();

    my $leaked = $self->tracker->live_objects;
    my @leaks = keys %$leaked;

    # XXX: Devel::Size seems to segfault Jifty at END time
    my $size = total_size([ @leaks ]) - $empty_array;

    push @requests, {
        id => 1 + @requests,
        url => $cgi->url(-absolute=>1,-path_info=>1),
        size => $size,
        objects => Dumper($leaked),
        time => scalar gmtime,
        leaks => \@leaks,
    };

    $self->generator(undef);
    $self->tracker(undef);
}

=head1 NAME

Jifty::Plugin::LeakTracker

=head1 DESCRIPTION

Memory leak detection and reporting for your Jifty app

=head1 USAGE

Add the following to your site_config.yml

 framework:
   Plugins:
     - LeakTracker: {}

This makes the following URLs available:

View the top-level leak report (how much each request has leaked)

    http://your.app/leaks

View the top-level leak report, including zero-leak requests

    http://your.app/leaks/all

View an individual request's detailed leak report (which objects were leaked)

    http://your.app/leaks/3

=head1 WARNING

If you use this in production, be sure to block off 'leaks' from
non-administrators. The full Data::Dumper output of the objects
leaked is available, which may of course contain sensitive information.

=head1 SEE ALSO

L<Jifty::Plugin::LeakTracker::View>, L<Jifty::Plugin::LeakTracker::Dispatcher>

=head1 COPYRIGHT AND LICENSE

Copyright 2007 Best Practical Solutions

This is free software and may be modified and distributed under the same terms as Perl itself.

=cut

1;

