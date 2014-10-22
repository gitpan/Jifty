use strict;
use warnings;

package Jifty::I18N;
use base 'Locale::Maketext';
use Locale::Maketext::Lexicon ();
use Email::MIME::ContentType;
use Encode::Guess qw(iso-8859-1);
use File::ShareDir 'module_dir';
use Jifty::Util;

=head1 NAME

Jifty::I18N - Internationalization framework for Jifty

=head1 SYNOPSIS

  # Whenever you need an internationalized string:
  print _('Hello, %1!', 'World');

In your Mason templates:

  <% _('Hello, %1!', 'World') %>

=head1 METHODS

=head2 C<_>

This module provides a method named C<_>, which allows you to quickly and easily include localized strings in your application. The first argument is the string to translated. If that string contains placeholders, the remaining arguments are used to replace the placeholders. The placeholders in the form of "%1" where the number is the number of the argument used to replace it:

  _('Welcome %1 to the %2', 'Bob', 'World');

This example would return the string "Welcome Bob to the World" if no translation is being performed.

=cut

=head2 new

Set up Jifty's internationalization for your application.  This pulls
in Jifty's PO files, your PO files and then exports the _ function into
the wider world.

=cut

my $DynamicLH;

our $loaded;

sub new {
    my $class = shift;
    my $self  = {};
    bless $self, $class;

    # XXX: this requires a full review, LML->get_handle is calling new
    # on I18N::lang each time, but we really shouldn't need to rerun
    # the import here.
    return $self if $loaded;

    my @import = map {( Gettext => $_ )} _get_file_patterns();
    ++$loaded;

    Locale::Maketext::Lexicon->import(
        {   '*' => \@import,
            _decode => 1,
            _auto   => 1,
            _style  => 'gettext',
        }
    );

    # Allow hard-coded languages in the config file
    my $lang = Jifty->config->framework('L10N')->{'Lang'};
    $lang = [defined $lang ? $lang : ()] unless ref($lang) eq 'ARRAY';

    my $lh = $class->get_handle(@$lang);

    $DynamicLH = \$lh unless @$lang; 
    $self->init;

    my $loc_method = sub {
        # Retain compatibility with people using "-e _" etc.
        return \*_ unless @_; # Needed for perl 5.8

        # When $_[0] is undef, return undef.  When it is '', return ''.
        no warnings 'uninitialized';
        return $_[0] unless (length $_[0]);

        local $@;
        # Force stringification to stop Locale::Maketext from choking on
        # things like DateTime objects.
        my @stringified_args = map {"$_"} @_;
        my $result = eval { $lh->maketext(@stringified_args) };
        if ($@) {
            warn $@;
            # Sometimes Locale::Maketext fails to localize a string and throws
            # an exception instead.  In that case, we just return the input.
            return join(' ', @stringified_args);
        }
        return $result;
    };

    {
        no strict 'refs';
        no warnings 'redefine';
        *_ = $loc_method;
    }
    return $self;
}

=head2 _get_file_patterns

Get list of patterns for all PO files in the project.
(Paths are gotten from the configuration variables and plugins).

=cut

sub _get_file_patterns {
    my @ret;

    push(@ret, Jifty->config->framework('L10N')->{'PoDir'});
    push(@ret, Jifty->config->framework('L10N')->{'DefaultPoDir'});

    # Convert relative paths to absolute ones
    @ret = map { Jifty::Util->absolute_path($_) } @ret;

    foreach my $plugin (Jifty->plugins) {
        my $dir = $plugin->po_root;
        next unless ($dir and -d $dir and -r $dir );
        push @ret, $dir ;
    }

    return ( map { $_ . '/*.po' } @ret );
}

=head2 get_language_handle

Get the lanauge language for this request.

=cut

sub get_language_handle {
    my $self = shift;
    $$DynamicLH = $self->get_handle() if $DynamicLH;
}

=head2 refresh

Used by L<Jifty::Handler> in DevelMode to reload F<.po> files whenever they
are modified on disk.

=cut

my $LAST_MODIFED = '';
sub refresh {
    my $modified = join(
        ',',
        #   sort map { $_ => -M $_ } map { glob("$_/*.po") } ( Jifty->config->framework('L10N')->{'PoDir'}, Jifty->config->framework('L10N')->{'DefaultPoDir'}
        sort map { $_ => -M $_ } map { glob($_) } _get_file_patterns()
    );
    if ($modified ne $LAST_MODIFED) {
        Jifty::I18N->new;
        $LAST_MODIFED = $modified;
    }
}



=head2 promote_encoding STRING [CONTENT-TYPE]

Return STRING promoted to our best-guess of an appropriate
encoding. STRING should B<not> have the UTF-8 flag set when passed in.

Optionally, you can pass a MIME content-type string as a second
argument. If it contains a charset= parameter, we will use that
encoding. Failing that, we use Encode::Guess to guess between UTF-8
and iso-latin-1. If that fails, and the string validates as UTF-8, we
assume that. Finally, we fall back on returning the string as is.

=cut

# XXX TODO This possibly needs to be more clever and/or configurable

sub promote_encoding {
    my $class = shift;
    my $string = shift;
    my $content_type = shift;

    $content_type = Email::MIME::ContentType::parse_content_type($content_type) if $content_type;
    my $charset = $content_type->{attributes}->{charset} if $content_type;

    # XXX TODO Is this the right thing? Maybe we should just return
    # the string as-is.
    Encode::_utf8_off($string);

    if($charset) {
        $string = Encode::decode($charset, $string);
    } else {
        my $encoding = Encode::Guess->guess($string);
        if(!ref($encoding)) {
            local $@;
            eval {
                # Try utf8
                $string = Encode::decode_utf8($string, 1);
            };
            if($@) {
                warn "Unknown encoding -- none specified, couldn't guess, not valid UTF-8";
            }
        } else {
            $string = $encoding->decode($string) if $encoding;
        }
    }

    return $string;
}

=head2 maybe_decode_utf8 STRING

Attempt to decode STRING as UTF-8. If STRING is not valid UTF-8, or
already contains wide characters, return it undecoded.

N.B: In an ideal world, we wouldn't need this function, since we would
know whether any given piece of input is UTF-8. However, the world is
not ideal.

=cut

sub maybe_decode_utf8 {
    my $class = shift;
    my $string = shift;

    local $@;
    eval {
        $string =  Encode::decode_utf8($string);
    };
    Carp::carp "Couldn't decode UTF-8: $@" if $@;
    return $string;
}

package Jifty::I18N::en;
use base 'Locale::Maketext';
our %Lexicon = ( _fallback => 1, _AUTO => 1 );

1;
