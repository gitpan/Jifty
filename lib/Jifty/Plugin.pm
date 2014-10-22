use strict;
use warnings;

package Jifty::Plugin;
use File::ShareDir 'module_dir';


=head1 NAME

Jifty::Plugin - Describes a plugin to the Jifty framework

=head1 DESCRIPTION

Plugins are like mini-apps.  They come in packages with share
directories which provide static and template files; they provide
actions; they have dispatcher rules.  To create the skeleton of a new
plugin, you can use the command:
    jifty plugin --name SomePlugin

To use a plugin in your Jifty application, find the C<Plugins:> line
in the C<config.yml> file:

      Plugins:
        - SpiffyThing: {}
        - SomePlugin:
            arguments: to
            the: constructor

The dispatcher for a plugin should live in
C<Jifty::Plugin::I<name>::Dispatcher>; it is written like any other
L<Jifty::Dispatcher>.  Plugin dispatcher rules are checked before the
application's rules; however, see L<Jifty::Dispatcher/Plugins and rule
ordering> for how to manually specify exceptions to this.

Actions and models under a plugin's namespace are automatically
discovered and made available to applications.

=cut

use File::ShareDir;

=head2 new

Sets up a new instance of this plugin.  This is called by L<Jifty>
after reading the configuration file, and is supplied whatever
plugin-specific settings were in the config file.  Note that because
plugins affect Mason's component roots, adding plugins during runtime
is not supported.

=cut

sub new {
    my $class = shift;
    
    # Get a classloader set up
    Jifty::ClassLoader->new(base => $class)->require;
    Jifty::Util->require($class->dispatcher);

    # XXX TODO: Add .po path

    my $self = bless {} => $class;
    $self->init(@_);
    return $self;
}


=head2 init [ARGS]

Called by L</new>, this does any custom configuration that the plugin
might need.  It is passed the same parameters as L</new>, gleaned from
the configuration file.

=cut

sub init {
    1;
}

=head2 new_request

Called right before every request.  By default, this adds the plugin's
actions to the list of allowed actions, using L<Jifty::API/allow>.

=cut

sub new_request {
    my $self = shift;
    my $class = ref($self) || $self;
    Jifty->api->allow(qr/^\Q$class\E::Action/);
}

sub _calculate_share {
    my $self = shift;
    my $class = ref($self);
    unless ( $self->{share} ) {
        local $@
            ; # We're just avoiding File::ShareDir's failure behaviour of dying
        eval { $self->{share} = module_dir($class) };
    }
    unless ( $self->{share} ) {
        local $@; # We're just avoiding File::ShareDir's failure behaviour of dying
        eval { $self->{share} = module_dir('Jifty') };
        if ( $self->{'share'} ) {
            my $class_to_path = $class;
            $class_to_path =~ s|::|/|g;
            $self->{share} .= "/plugins/" . $class_to_path;
        }
    }
    return $self->{share};
}


=head2 template_root

Returns the root of the C<HTML::Mason> template directory for this plugin

=cut

sub template_root {
    my $self = shift;
    my $dir =  $self->_calculate_share();
    return unless $dir;
    return $dir."/web/templates";
}

=head2 po_root

Returns the plugin's message catalog directory. Returns undef if it doesn't exist.

=cut

sub po_root {
    my $self = shift;
    my $dir = $self->_calculate_share();
    return unless $dir;
    return $dir."/po";
}

=head2 template_class

Returns the Template::Declare view package for this plugin

=cut

sub template_class {
    my $self = shift;
    my $class = ref($self) || $self;
    return $class.'::View';
}


=head2 static_root

Returns the root of the static directory for this plugin

=cut

sub static_root {
    my $self = shift;
    my $dir =  $self->_calculate_share();
    return unless $dir;
    return $dir."/web/static";
}

=head2 dispatcher

Returns the classname of the dispatcher class for this plugin

=cut

sub dispatcher {
    my $self = shift;
    my $class = ref($self) || $self;
    return $class."::Dispatcher";
}

=head2 prereq_plugins

Returns an array of plugin module names that this plugin depends on.

=cut

sub prereq_plugins {
    return ();
}

1;
