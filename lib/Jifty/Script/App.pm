use warnings;
use strict;

package Jifty::Script::App;
use base qw'App::CLI::Command Class::Accessor';

use File::Copy;
use Jifty::Config;
use Jifty::YAML;

__PACKAGE__->mk_accessors(qw/prefix dist_name mod_name/);


=head1 NAME

Jifty::Script::App - Create the skeleton of a Jifty application

=head1 DESCRIPTION

Creates a skeleton of a new Jifty application.  See
L<Jifty::Manual::Tutorial> for an example of its use.

=head2 options

This script only takes one option, C<--name>, which is required; it is
the name of the application to create.  Jifty will create a directory
with that name, and place all of the files it creates inside that
directory.

=cut

sub options {
    (
     'n|name=s' => 'name',
    )
}

=head2 run

Create a directory for the application, a skeleton directory
structure, and a C<Makefile.PL> for you application.

=cut

sub run {
    my $self = shift;

    $self->prefix( $self->{name} ||''); 

    unless ($self->prefix =~ /\w+/ ) { die "You need to give your new Jifty app a --name"."\n";}

    # Turn my-app-name into My::App::Name.

    $self->mod_name (join ("::", map { ucfirst } split (/\-/, $self->prefix)));
    my $dist = $self->mod_name;
    $self->dist_name($self->prefix);

    print("Creating new application ".$self->mod_name."\n");
    $self->_make_directories();
    $self->_install_jifty_binary();
    $self->_write_makefile();
    $self->_write_config();


}

sub _install_jifty_binary {
    my $self = shift;
    my $prefix = $self->prefix;
    # Copy our running copy of 'jifty' to bin/jifty
    copy($0, "$prefix/bin/jifty");
    # Mark it executable
    chmod(0555, "$prefix/bin/jifty");
}



sub _write_makefile {
    my $self = shift;
    my $mod_name = $self->mod_name;
    my $prefix = $self->prefix;
    # Write a makefile
    open(MAKEFILE, ">$prefix/Makefile.PL") or die "Can't write Makefile.PL: $!";
    print MAKEFILE <<"EOT";
use inc::Module::Install;
name('$mod_name');
version('0.01');
requires('Jifty' => '@{[$Jifty::VERSION]}');

WriteAll;
EOT
    close MAKEFILE;
} 

sub _make_directories {
    my $self = shift;

    mkdir($self->prefix);
    my @dirs = qw( lib );
    my @dir_parts = split('::',$self->mod_name);
    my $lib_dir = "";
    foreach my $part (@dir_parts) {
        $lib_dir .= '/' if length $lib_dir;
        $lib_dir .=  $part;
        push @dirs, "lib/$lib_dir";
    }

    @dirs = (@dirs, $self->_directories); 

    foreach my $dir (@dirs) {
        $dir =~ s/__APP__/$lib_dir/;
        print("Creating directory $dir\n");
        mkdir( $self->prefix."/$dir") or die "Can't create ". $self->prefix."/$dir: $!";

    }
}
sub _directories {
    return qw(
        bin
        etc
        doc
        log
        var
        var/sessions
        var/mason
        web
        web/templates
        web/static
        lib/__APP__/Model
        lib/__APP__/Action
        t
    );
}


sub _write_config {
    my $self = shift;
    my $cfg = Jifty::Config->new(load_config => 0);
    my $default_config = $cfg->guess($self->dist_name);
    my $file = join("/",$self->prefix, 'etc','config.yml');
    print("Creating configuration file $file\n");
    Jifty::YAML::DumpFile($file => $default_config);

}


1;

