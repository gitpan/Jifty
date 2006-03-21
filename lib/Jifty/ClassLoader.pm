use warnings;
use strict;

package Jifty::ClassLoader;

=head1 NAME

Jifty::ClassLoader - Loads the application classes

=head1 DESCRIPTION

C<Jifty::ClassLoader> loads all of the application's model and action
classes, generating classes on the fly for Collections of pre-existing
models.

=head2 new

Returns a new ClassLoader object.  Doing this installs a hook into
C<@INC> that allows L<Jifty::ClassLoader> to dynamically create needed
classes if they do not exist already.

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;

    push @INC, $self;
    return $self;
}

=head2 INC

The hook that is called when a module has been C<require>'d that
cannot be found on disk.  The following stub classes are
auto-generated:

=over

=item I<Application>

An empty application base class is created that doen't provide any
methods or inherit from anything.

=item I<Application>::Record

An empty class that descends from L<Jifty::Record> is created.

=item I<Application>::Collection

An empty class that descends from L<Jifty::Collection> is created.

=item I<ApplicationClass::Notification>.

An empty class that descends from L<Jifty::Notification>.

=item I<ApplicationClass::Dispatcher>.

An empty class that descends from L<Jifty::Dispatcher>.

=item I<Application>::Bootstrap

An empty class that descends from L<Jifty::Bootstrap>.

=item I<CurrentUserClass> (generally I<Application>::CurrentUser)

...where I<CurrentUserClass> is defined by the C<CurrentUserClass>
from the L<configuration file|Jifty::Config>.  This defaults to an
empty class which is a subclass of L<Jifty::CurrentUser>.

=item I<Application>::Model::I<Anything>Collection

If C<I<Application>::Model::I<Something>> is a valid model class, then
it creates a subclass of L<Jifty::Collection> whose C<record_class> is
C<I<Application>::Model::I<Something>>.

=item I<Application>::Action::(Create or Update or Delete)I<Anything>

If C<I<Application>::Model::I<Something>> is a valid model class, then
it creates a subclass of L<Jifty::Action::Record::Create>,
L<Jifty::Action::Record::Update>, or L<Jifty::Action::Record::Delete>
whose I<record_class> is C<I<Application>::Model::I<Something>>.

=back

=cut

# This subroutine's name is fully qualified, as perl will ignore a 'sub INC'
sub Jifty::ClassLoader::INC {
    my ( $self, $module ) = @_;
    my $ApplicationClassPrefix = Jifty->config->framework('ApplicationClass');
    my $ActionBasePath   = Jifty->config->framework('ActionBasePath');
    my $CurrentUserClass = Jifty->config->framework('CurrentUserClass');
    my $CurrentUserClassPath =Jifty->config->framework('CurrentUserClass') .".pm";
    $CurrentUserClassPath =~ s!::!/!g;
    return undef unless ( $module and $ApplicationClassPrefix );


    # Canonicalize $module to :: style rather than / and .pm style;
    
    $module =~ s/.pm$//;
    $module =~ s{/}{::}g;

    if ( $module =~ m!^($ApplicationClassPrefix)$! ) {
        return $self->return_class( "use warnings; use strict; package " . $ApplicationClassPrefix . ";\n"." 1;" );
    } 
#    elsif ( $module =~ m!^($ActionBasePath)$! ) {
#        return $self->return_class( "use warnings; use strict; package " . $ActionBasePath . ";\n".
#            "use base qw/Jifty::Action/; sub _autogenerated { 1 };\n"."1;" );
#    } 
    elsif ( $module =~ m!^(?:$ApplicationClassPrefix)::(Record|Collection|Notification|Dispatcher|Bootstrap)$! ) {
        return $self->return_class( "use warnings; use strict; package " . $ApplicationClassPrefix . "::". $1.";\n".
            "use base qw/Jifty::$1/; sub _autogenerated { 1 };\n"."1;" );
    } 

    elsif ( $module =~ m!^$CurrentUserClass$! or $module =~ m!^$CurrentUserClassPath$!) {
      return $self->return_class( "package " . $CurrentUserClass . ";\n" . "use base 'Jifty::CurrentUser';\n" . " 1;" );
      }
    elsif ( $module
        =~ m!^($ApplicationClassPrefix)::Model::(\w+)Collection$!
        )
    {

        # Auto-create Collection classes
        my $record_class = $ApplicationClassPrefix . "::Model::" . $2;
        return $self->return_class( "package " . $ApplicationClassPrefix . "::Model::" . $2 . "Collection;\n"."use base qw/@{[$ApplicationClassPrefix]}::Collection/;\n sub record_class { '@{[$ApplicationClassPrefix]}::Model::$2' }\n"." 1;"
        );

    } elsif ( $module
        =~ m!^($ApplicationClassPrefix)::Action::(Create|Update|Delete)([^\.:]+)$!
        )
    {
         
        # Auto-create CRUD classes
        my $modelclass = $ApplicationClassPrefix . "::Model::" . $3;
        Jifty::Util->require($modelclass);

        return undef unless eval {$modelclass->table}; #self->{models}{$modelclass};

        my $class = $ActionBasePath ."::".$2.$3;
        return $self->return_class( "package " . $ActionBasePath . "::$2$3;\n"
                . "use base qw/Jifty::Action::Record::$2/;\n"
                . "sub record_class {'$modelclass'};\n"
                . "1;" );

    }
    return undef;
}

=head2 return_class CODE

A helper method; takes CODE as a string and returns an open filehandle
containing that CODE.

=cut


sub return_class {
    my $self = shift;
    my $content = shift;
    open my $fh, '<', \$content;
    return $fh;

}

=head2 require

Loads all of the application's Actions and Models.  It additionally
C<require>'s all Collections and Create/Update actions for each Model
base class -- which will auto-create them using the above code if they
do not exist on disk.

=cut

sub require {
    my $self = shift;
    
    my $ApplicationClassPrefix = Jifty->config->framework('ApplicationClass');
    # if we don't even have an application class, this trick will not work
    return unless  ($ApplicationClassPrefix); 
    Jifty::Util->require($ApplicationClassPrefix);
    Jifty::Util->require(Jifty->config->framework('CurrentUserClass'));

    my $ActionBasePath = Jifty->config->framework('ActionBasePath');

    Module::Pluggable->import(
        search_path =>
          [ $ActionBasePath, map { $ApplicationClassPrefix . "::" . $_ } 'Model', 'Action', 'Notification' ],
        require => 1,
        inner => 0
    );
    $self->{models} = {map {($_ => 1)} grep {/^($ApplicationClassPrefix)::Model::(.*)$/ and not /Collection$/} $self->plugins};
    for my $full (keys %{$self->{models}}) {
        my($short) = $full =~ /::Model::(.*)/;
        Jifty::Util->require($full . "Collection");
        Jifty::Util->require($ActionBasePath . "::" . $_ . $short)
            for qw/Create Update Delete/;
    }

}

1;
