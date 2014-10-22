package Jifty::Plugin::SQLQueries;
use strict;
use warnings;
use base 'Jifty::Plugin';
use List::Util 'sum';

sub prereq_plugins { 'RequestInspector' }

sub init {
    my $self = shift;
    return if $self->_pre_init;

    Jifty->add_trigger(
        post_init => \&post_init
    );
}

sub post_init {
    Jifty->handle or return;

    require Carp;

    Jifty->handle->log_sql_statements(1);
    Jifty->handle->log_sql_hook(SQLQueryPlugin => sub {
        my ($time, $statement, $bindings, $duration) = @_;
        __PACKAGE__->log->debug(sprintf 'Query (%.3fs): "%s", with bindings: %s',
                            $duration,
                            $statement,
                            join ', ',
                                map { defined $_ ? $_ : 'undef' } @$bindings,
        );
        return Carp::longmess("Query");
    });
}

sub inspect_before_request {
    Jifty->handle->clear_sql_statement_log;
}

sub inspect_after_request {
    return [ Jifty->handle->sql_statement_log ];
}

sub inspect_render_summary {
    my $self = shift;
    my $log = shift;

    my $count = @$log;
    my $seconds = sprintf '%.2g', sum map { $_->[3] } @$log;

    return _("%quant(%1,query,queries) taking %2s", $count, $seconds);
}

sub inspect_render_analysis {
    my $self = shift;
    my $log = shift;
    my $id = shift;

    Jifty::View::Declare::Helpers::render_region(
        name => 'sqlqueries',
        path => '/__jifty/admin/requests/queries',
        args => {
            id => $id,
        },
    );
}

1;

__END__

=head1 NAME

Jifty::Plugin::SQLQueries - Inspect your app's SQL queries

=head1 DESCRIPTION

This plugin will log each SQL query, its duration, its bind parameters, and its stack trace. Such reports are available at:

    http://your.app/__jifty/admin/requests

=head1 USAGE

Add the following to your site_config.yml

 framework:
   Plugins:
     - SQLQueries: {}

=head1 METHODS

=head2 init

Sets up a L</post_init> hook.

=head2 inspect_before_request

Clears the query log so we don't log any unrelated previous queries.

=head2 inspect_after_request

Stash the query log.

=head2 inspect_render_summary

Display how many queries and their total time.

=head2 inspect_render_analysis

Render a template with all the detailed information.

=head2 post_init

Tells L<Jifty::DBI> to log queries in a way that records stack traces.

=head2 prereq_plugins

This plugin depends on L<Jifty::Plugin::RequestInspector>.

=head1 COPYRIGHT AND LICENSE

Copyright 2007-2009 Best Practical Solutions

This is free software and may be modified and distributed under the same terms as Perl itself.

=cut

