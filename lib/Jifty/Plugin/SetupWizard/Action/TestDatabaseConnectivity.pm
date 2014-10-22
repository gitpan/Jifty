package Jifty::Plugin::SetupWizard::Action::TestDatabaseConnectivity;
use strict;
use warnings;
use base 'Jifty::Action';

use Jifty::Param::Schema;
use Jifty::Action schema {
    param driver =>
        is mandatory,
        type is 'text',
        default is defer { Jifty->config->framework('Database')->{Driver} };

    param database =>
        is mandatory,
        type is 'text',
        default is defer { Jifty->config->framework('Database')->{Database} };

    param host =>
        type is 'text',
        default is defer { Jifty->config->framework('Database')->{Host} };

    param port =>
        type is 'integer',
        default is defer { Jifty->config->framework('Database')->{Port} };

    param user =>
        type is 'text',
        default is defer { Jifty->config->framework('Database')->{User} };

    param password =>
        type is 'password',
        default is defer { Jifty->config->framework('Database')->{Password} };

    param requiressl =>
        type is 'boolean',
        default is defer { Jifty->config->framework('Database')->{RequireSSL} };
};

sub take_action {
    my $self = shift;

    # Remove empty arguments (empty port confuses DBI)
    # Maybe should go in Jifty::DBI. it does handle undef..
    my %args = %{ $self->argument_values };
    for my $key (keys %args) {
        delete $args{$key} if !defined($args{$key}) || !length($args{$key});
    }

    my $handle = Jifty::DBI::Handle->new;
    my $ok = eval {
        local $SIG{__DIE__};

        # Connect returns undef if there's already a connection, so we
        # only report failure to connect if an exception was thrown
        $handle->connect(%args);

        1;
    };
    my $error = $@;

    # database will be created, so not worth complaining about this
    $ok = 1 if $error =~ /Connection failed: Unknown database '/
            || $error =~ /Connection failed: .* database ".*" does not exist/;

    if (!$ok) {
        $error ||= _("No handle created");
        warn $error;
        $error =~ s/ at .* line \d+$//;
        return $self->result->error($error);
    }

    $self->result->message(_('Connection successful'));
}

1;

__END__

=head1 NAME

Jifty::Plugin::SetupWizard::Action::TestDatabaseConnectivity - Test database connectivity action

=head1 METHODS

=head2 take_action

Tests the database connectivity!

=cut

