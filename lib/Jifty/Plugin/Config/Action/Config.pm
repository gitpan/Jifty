package Jifty::Plugin::Config::Action::Config;
use strict;
use warnings;

use base qw/Jifty::Action/;
use UNIVERSAL::require;
use Jifty::YAML;
use File::Spec;
use Scalar::Defer;

=head1 NAME

Jifty::Plugin::Config::Action::Config - Register config

=head1 METHODS

=head2 arguments

Provides a single argument, C<config>, which is a textarea with
Jifty's L<YAML> configuration in it.

=cut

sub arguments {
    my $self = shift;
    return $self->{__cached_arguments} if ( $self->{__cached_arguments} );
    my $args = {
        'config' => {
            label         => '',           # don't show label
            render_as     => 'Textarea',
            rows          => 60,
            default_value => defer {
                local $/;
                open my $fh, '<', Jifty::Util->app_root . '/etc/config.yml';
                return <$fh>;
            }
        },
    };

    return $self->{__cached_arguments} = $args;
}

=head2 take_action

Attempts to update the application's F<etc/config.yml> file with the
new configuration.

=cut

sub take_action {
    my $self = shift;

    if ( $self->has_argument('config') ) {
        my $new_config = $self->argument_value( 'config' );
        $new_config =~ s/\r\n/\n/g; #textarea gives us dos format
        eval { Jifty::YAML::Load( $new_config ) };
        if ( $@ ) {
# invalid yaml
            $self->result->message( _( "invalid yaml" ) );
            $self->result->failure(1);
            return;
        }
        else {
            if ( open my $fh, '>', Jifty::Util->app_root . '/etc/config.yml' ) {
                print $fh $new_config;
                close $fh;
            }
            else {
                $self->result->message(
                    _("can't write to etc/config.yml: $1") );
                $self->result->failure(1);
                return;
            }
        }
    }
    $self->report_success;

    Jifty->config->load;

    return 1;
}

=head2 report_success

Reports that the action succeeded.

=cut

sub report_success {
    my $self = shift;

    # Your success message here
    $self->result->message('Success');
}

1;
