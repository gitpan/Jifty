use warnings;
use strict;

package Jifty::Util;

=head1 NAME

Jifty::Util - Things that don't fit anywhere else

=head1 DESCRIPTION


=cut

use Jifty::Everything;
use File::Spec;
use File::ShareDir;
use Cwd ();

# Trivial memoization to ward off evil Cwd calls.
use vars qw/%ABSOLUTE_PATH $JIFTY_ROOT $SHARE_ROOT $APP_ROOT/;


=head2 absolute_path PATH

C<absolute_path> converts PATH into an absolute path, relative to the
application's root (as determined by L</app_root>)  This can be called
as an object or class method.

=cut

sub absolute_path {
    my $self = shift;
    my $path = shift || '';

    return $ABSOLUTE_PATH{$path} if (exists $ABSOLUTE_PATH{$path});
    return $ABSOLUTE_PATH{$path} = File::Spec->rel2abs($path , Jifty::Util->app_root);
} 

=head2 jifty_root

Returns the root directory that Jifty has been installed into.
Uses %INC to figure out where Jifty.pm is.

=cut

sub jifty_root {
    my $self = shift;
    unless ($JIFTY_ROOT) {
    my ($vol,$dir,$file) = File::Spec->splitpath($INC{"Jifty.pm"});
    $JIFTY_ROOT = File::Spec->rel2abs($dir);   
}
    return ($JIFTY_ROOT);
}


=head2 share_root

Returns the 'share' directory of the installed Jifty module.  This is
currently only used to store the common Mason components.

=cut

sub share_root {
    my $self = shift;

    return $SHARE_ROOT ||=  File::Spec->rel2abs( File::ShareDir::module_dir('Jifty') );
}

=head2 app_root

Returns the application's root path.  This is done by searching upward
from the current directory, looking for a directory which contains a
C<bin/jifty>.  Failing that, it searches upward from wherever the
executable was found.

It C<die>s if it can only find C</usr> or C</usr/local> which fit
these criteria.

=cut

sub app_root {
    my $self = shift;


    return $APP_ROOT if ($APP_ROOT);
    
    my @roots;

    push( @roots, Cwd::cwd() );

    eval { require FindBin };
    if ( my $err = $@ ) {

        #warn $@;
    } else {
        push @roots, $FindBin::Bin;
    }

    for (@roots) {
        my @root = File::Spec->splitdir($_);
        while (@root) {
            my $try = File::Spec->catdir( @root, "bin", "jifty" );
            if (    -e $try
                and -x $try
                and $try ne "/usr/bin/jifty"
                and $try ne "/usr/local/bin/jifty" )
            {
                return $APP_ROOT = File::Spec->catdir(@root);
            }
            pop @root;
        }
    }
    warn "Can't guess application root from current path ("
        . Cwd::cwd()
        . ") or bin path ($FindBin::Bin)\n";
}

=head2 default_app_name

Returns the default name of the application.  This is the name of the
application's root directory, as defined by L</app_root>.

=cut

sub default_app_name {
    my $self = shift;
    my @root = File::Spec->splitdir( Jifty::Util->app_root);
    return pop @root;
}

=head2 make_path PATH

When handed a directory, creates that directory, starting as far up the 
chain as necessary. (This is what 'mkdir -p' does in your shell)

=cut

sub make_path {
    my $self = shift;
    my $whole_path = shift;
    my @dirs = File::Spec->splitdir( $whole_path );
    my $path ='';
    foreach my $dir ( @dirs) {
        $path = File::Spec->catdir($path, $dir);
        if (-d $path) { next }
        if (-w $path) { die "$path not writable"; }
        
        
        mkdir($path) || die "Couldn't create directory $path: $!";
    }

}

=head1 AUTHOR

Various folks at Best Practical Solutions, LLC.

=cut

1;
