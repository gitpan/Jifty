use warnings;
use strict;
use File::MMagic ();
use MIME::Types ();
use Compress::Zlib ();
use HTTP::Date ();


package Jifty::View::Static::Handler;

use base qw/Jifty::Object/;

our $mime  = MIME::Types->new();
our $magic = File::MMagic->new();

=head1 NAME

Jifty::View::Static::Handler

head1 DESCRIPTION

This class takes care of serving out static files for a Jifty application. 

When fully operational, it will use an algorithm along the lines of the following:

* Static files are served out of a separate root
* If static files go through apache:
    * How do we merge together the two static roots?
* If static files go through Jifty::Handler
    * We need a flag to allow them to go through the dispatcher, too
    * return "True" (304) for if-modified-since unless develmode.
    * if the browser accepts gzipped data,
        see if we have a cached gzipped copy
            if so, send it
        see if we have a marker indicating that gzip is a lose
            if so, send uncompressed

        gzip the content
        send the gzipped content
     * if the browser doesn't accept gzipped content
        send the content uncompressed


=cut


=head2 new

Create a new static file handler. Likely, only the C<Jifty::Handler> needs to do this.

=cut
sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;
}


=head2 handle_request $path

Handle a request for C<$path>. If we can't find a static file of that name, return undef.


=cut

sub handle_request {
    my $self = shift;
    my $path = shift;

    #if ( Jifty->handler->cgi->http('If-Modified-Since') and not Jifty->config->framework('DevelMode') ) { $self->respond_not_modified(); }

    my $local_path = $self->file_path($path);
    unless ($local_path) {
        return undef;
    }

    my $mime_type = $self->mime_type($local_path);
    
    if ( $self->client_accepts_gzipped_content and $mime_type =~ m!^(text/|application/x-javascript)! ) {
        return $self->send_file($local_path, $mime_type, 'gzip');
    } else {
        return  $self->send_file($local_path, $mime_type, 'uncompressed');
    }

}


=head2 client_accepts_gzipped_content

Returns true if it looks like the client accepts gzip encoding. Otherwise, returns false.


=cut


sub client_accepts_gzipped_content {
    my $self = shift;
    no warnings 'uninitialized';
    return Jifty->handler->cgi->http('Accept-Encoding') =~ /\bgzip\b/;
}


=head2 file_path $path

Returns the system path for C<$path>, inside the application's static root or, failing that, Jifty's static root.
Returns undef if it can't find the file in either path.

=cut

sub file_path {
    my $self    = shift;
    my $file    = shift;
    my @options = (qw(StaticRoot DefaultStaticRoot));

    # Chomp a leading "/static" - should this be configurable?
    $file =~ s/^\/*?static//; 

    foreach my $path (@options) {

        my $abspath = Jifty::Util->absolute_path(
            Jifty->config->framework('Web')->{$path} . "/" . $file );

        return $abspath if ( -f $abspath && -r $abspath );

    }
    return undef;

}

=head2 mime_type $path

Returns the mime type of the file whose path on disk is C<$path>. Tries to use
L<MIME::Types> to guess first. If that fails, it falls back to C<File::MMagic>.

=cut

sub mime_type {
    my $self       = shift;
    my $local_path = shift;

    my $mimeobj   = $mime->mimeTypeOf($local_path);
    my $mime_type = (
          $mimeobj
        ? $mimeobj->type
        : $magic->checktype_filename($local_path)
    );

    return ($mime_type);
}


=head2 send_file $path $mimetype $compression

Print C<$path> to STDOUT (the client), identified with a mimetype of C<$mimetype>.

If C<$compression> is C<gzip>, gzip the output stream.


=cut


sub send_file {
    my $self       = shift;
    my $local_path = shift;
    my $mime_type  = shift;
    my $compression = shift;


    my $fh = IO::File->new( $local_path, 'r' );
    if ( defined $fh ) {
        binmode $fh;

        # This is designed to work under CGI or FastCGI; will need an
        # abstraction for mod_perl

        # Clear out the mason output, if any
        Jifty->web->mason->clear_buffer if Jifty->web->mason;

        my @file_info = stat($local_path);
        my $apache = Jifty->handler->apache;

        $apache->header_out( Status => 200 );
        $apache->content_type($mime_type);
        my $now = time();
        $apache->header_out(Expires =>  HTTP::Date::time2str($now + 31536000));  # Expire in a year
        $apache->header_out('Last-Modified' =>  HTTP::Date::time2str( $file_info[9]));
        $apache->header_out('Content-Length' => $file_info[7]) unless ($compression eq 'gzip');  

        $apache->header_out( "Content-Encoding" => "gzip") if ($compression eq 'gzip');
        $apache->send_http_header();

        if ($compression eq 'gzip') {
        undef $/;
        binmode STDOUT;
        # XXX TODO: Cache this
        print STDOUT Compress::Zlib::memGzip(<$fh>);
        } else{
            $apache->send_fd($fh);
        }
        close($fh);
        return 1;
    } else {
        return undef;
    }
}


=head2 send_not_modified

Sends a "304 Not modified" response to the browser, telling it to use a cached copy.

=cut

sub send_not_modified {
    my $self = shift;
    Jifty->handler->apache->header_out( Status => 304 );
    return 1;

}

1;
