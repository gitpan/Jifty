package Jifty::Plugin::REST::Dispatcher;
use warnings;




use CGI qw( start_html end_html ol ul li a dl dt dd );
use Carp;
use Jifty::Dispatcher -base;
use Jifty::YAML ();
use Jifty::JSON ();
use Data::Dumper ();
use XML::Simple;

before qr{^ (/=/ .*) \. (js|json|yml|yaml|perl|pl) $}x => run {
    $ENV{HTTP_ACCEPT} = $2;
    dispatch $1;
};

before POST qr{^ (/=/ .*) ! (DELETE|PUT|GET|POST|OPTIONS|HEAD|TRACE|CONNECT) $}x => run {
    $ENV{REQUEST_METHOD} = $2;
    dispatch $1;
};

on GET    '/=/model/*/*/*/*' => \&show_item_field;
on GET    '/=/model/*/*/*'   => \&show_item;
on GET    '/=/model/*/*'     => \&list_model_items;
on GET    '/=/model/*'       => \&list_model_columns;
on GET    '/=/model'         => \&list_models;

on PUT    '/=/model/*/*/*' => \&replace_item;
on DELETE '/=/model/*/*/*' => \&delete_item;

on GET    '/=/action/*'    => \&list_action_params;
on GET    '/=/action'      => \&list_actions;
on POST   '/=/action/*'    => \&run_action;


=head2 list PREFIX items

Takes a URL prefix and a set of items to render. passes them on.

=cut



sub list {
    my $prefix = shift;
    outs($prefix, \@_)
}



=head2 outs PREFIX DATASTRUCTURE

TAkes a url path prefix and a datastructure.  Depending on what content types the other side of the HTTP connection can accept,
renders the content as yaml, json, javascript, perl, xml or html.

=cut


sub outs {
    my $prefix = shift;
    my $accept = ($ENV{HTTP_ACCEPT} || '');
    my $apache = Jifty->handler->apache;
    my @prefix;
    my $url;

    if($prefix) {
        @prefix = map {s/::/./g; $_} @$prefix;
         $url    = Jifty->web->url(path => join '/', '=',@prefix);
    }



    if ($accept =~ /ya?ml/i) {
        $apache->header_out('Content-Type' => 'text/x-yaml; charset=UTF-8');
        $apache->send_http_header;
        print Jifty::YAML::Dump(@_);
    }
    elsif ($accept =~ /json/i) {
        $apache->header_out('Content-Type' => 'application/json; charset=UTF-8');
        $apache->send_http_header;
        print Jifty::JSON::objToJson( @_, { singlequote => 1 } );
    }
    elsif ($accept =~ /j(?:ava)?s|ecmascript/i) {
        $apache->header_out('Content-Type' => 'application/javascript; charset=UTF-8');
        $apache->send_http_header;
        print 'var $_ = ', Jifty::JSON::objToJson( @_, { singlequote => 1 } );
    }
    elsif ($accept =~ /perl/i) {
        $apache->header_out('Content-Type' => 'application/x-perl; charset=UTF-8');
        $apache->send_http_header;
        print Data::Dumper::Dumper(@_);
    }
    elsif ($accept =~  qr|^(text/)?xml$|i) {
        $apache->header_out('Content-Type' => 'text/xml; charset=UTF-8');
        $apache->send_http_header;
        print render_as_xml(@_);
    }
    else {
        $apache->header_out('Content-Type' => 'text/html; charset=UTF-8');
        $apache->send_http_header;
        print render_as_html($prefix, $url, @_);
    }

    last_rule;
}

our $xml_config = { SuppressEmpty => '',
                    NoAttr => 1 };

=head2 render_as_xml DATASTRUCTURE

Attempts to render DATASTRUCTURE as simple, tag-based XML.

=cut

sub render_as_xml {
    my $content = shift;

    if (ref($content) eq 'ARRAY') {
        return XMLout({value => $content}, %$xml_config);
    }
    elsif (ref($content) eq 'HASH') {
        return XMLout($content, %$xml_config);
    } else {
        return XMLout({$content}, %$xml_config)
    }
}


=head2 render_as_html PREFIX URL DATASTRUCTURE

Attempts to render DATASTRUCTURE as simple semantic HTML suitable for humans to look at.

=cut

sub render_as_html {
    my $prefix = shift;
    my $url = shift;
    my $content = shift;
    if (ref($content) eq 'ARRAY') {
        return start_html(-encoding => 'UTF-8', -declare_xml => 1, -title => 'models'),
              ul(map {
                  li($prefix ?
                     a({-href => "$url/".Jifty::Web->escape_uri($_)}, Jifty::Web->escape($_))
                     : Jifty::Web->escape($_) )
              } @{$content}),
              end_html();
    }
    elsif (ref($content) eq 'HASH') {
        return start_html(-encoding => 'UTF-8', -declare_xml => 1, -title => 'models'),
              dl(map {
                  dt($prefix ?
                     a({-href => "$url/".Jifty::Web->escape_uri($_)}, Jifty::Web->escape($_))
                     : Jifty::Web->escape($_)),
                  dd(html_dump($content->{$_})),
              } sort keys %{$content}),
              end_html();
    }
    else {
        return start_html(-encoding => 'UTF-8', -declare_xml => 1, -title => 'models'),
              Jifty::Web->escape($content),
              end_html();
    }
}


=head2 html_dump DATASTRUCTURE

Recursively render DATASTRUCTURE as some simple html dls and ols. 

=cut


sub html_dump {
    my $content = shift;
    if (ref($content) eq 'ARRAY') {
        ul(map {
            li(html_dump($_))
        } @{$content});
    }
    elsif (ref($content) eq 'HASH') {
        dl(map {
            dt(Jifty::Web->escape($_)),
            dd(html_dump($content->{$_})),
        } sort keys %{$content}),
    } elsif (ref($content) && $content->isa('Jifty::Collection')) {
        return  ol( map { li( html_dump_record($_))  } @{$content->items_array_ref});
        
    } elsif (ref($content) && $content->isa('Jifty::Record')) {
          return   html_dump_record($content);
    }
    else {
        Jifty::Web->escape($content);
    }
}

=head2 html_dump_record Jifty::Record

Returns a nice simple HTML definition list of the keys and values of a Jifty::Record object.

=cut


sub html_dump_record {
    my $item = shift;
     my %hash = $item->as_hash;

     return  dl( map {dt($_), dd($hash{$_}) } keys %hash )
}

=head2 action ACTION

Canonicalizes ACTION into the form preferred by the code. (Cleans up casing, canonicalizing, etc. Returns 404 if it can't work its magic

=cut


sub action {  _resolve($_[0], 'Jifty::Action', Jifty->api->actions) }

=head2 model MODEL

Canonicalizes MODEL into the form preferred by the code. (Cleans up casing, canonicalizing, etc. Returns 404 if it can't work its magic

=cut

sub model  { _resolve($_[0], 'Jifty::Record', Jifty->class_loader->models) }

sub _resolve {
    my $name = shift;
    my $base = shift;
    return $name if $name->isa($base);

    $name =~ s/\W+/\\W+/g;

    foreach my $cls (@_) {
        return $cls if $cls =~ /$name$/i;
    }

    abort(404);
}


=head2 list_models

Sends the user a list of models in this application, with the names transformed from Perlish::Syntax to Everything.Else.Syntax

=cut

sub list_models {
    list(['model'], map {s/::/./g; $_ } Jifty->class_loader->models);
}

our @column_attrs = 
qw(    name
    type
    default
    validator
    readable writable
    length
    mandatory
    virtual
    distinct
    sort_order
    refers_to by
    alias_for_column
    aliased_as
    since until

    label hints render_as
    valid_values
);


=head2 list_model_columns

Sends the user a nice list of all columns in a given model class. Exactly which model is shoved into $1 by the dispatcher. This should probably be improved.


=cut

sub list_model_columns {
    my ($model) = model($1);

    my %cols;
    map {
            my $col = $_;
            $cols{$col->name} = { map { $_ => $col->$_() } @column_attrs} ;
    } $model->new->columns;

    outs(
        [ 'model', $model ], \%cols
    );
}

=head2 list_model_items MODELCLASS COLUMNNAME

Returns a list of items in MODELCLASS sorted by COLUMNNAME, with only COLUMNAME displayed.  (This should have some limiting thrown in)

=cut


sub list_model_items {

    # Normalize model name - fun!
    my ( $model, $column ) = ( model($1), $2 );
    my $col = $model->new->collection_class->new;
    $col->unlimit;
    $col->columns($column);
    $col->order_by( column => $column );

    list( [ 'model', $model, $column ],
        map { $_->$column() } @{ $col->items_array_ref || [] } );
}


=head2 show_item_field $model, $column, $key, $field

Loads up a model of type C<$model> which has a column C<$column> with a value C<$key>. Returns the value of C<$field> for that object. 
Returns 404 if it doesn't exist.



=cut

sub show_item_field {
    my ( $model, $column, $key, $field ) = ( model($1), $2, $3, $4 );
    my $rec = $model->new;
    $rec->load_by_cols( $column => $key );
    $rec->id          or abort(404);
    $rec->can($field) or abort(404);
    outs( [ 'model', $model, $column, $key, $field ], $rec->$field());
}

=head2 show_item $model, $column, $key

Loads up a model of type C<$model> which has a column C<$column> with a value C<$key>. Returns  all columns for the object

Returns 404 if it doesn't exist.

=cut

sub show_item {
    my ($model, $column, $key) = (model($1), $2, $3);
    my $rec = $model->new;
    $rec->load_by_cols( $column => $key );
    $rec->id or abort(404);
    outs( ['model', $model, $column, $key],  { map {$_ => $rec->$_()} map {$_->name} $rec->columns});
}


=head2 replace_item

UNIMPLEMENTED

=cut

sub replace_item {
    die "hey replace item";
}

=head2 delete_item

UNIMPLEMENTED

=cut

sub delete_item {
    die "hey delete item";
}

=head2 list_actions

Returns a list of all actions allowed to the current user. (Canonicalizes Perl::Style to Everything.Else.Style).

=cut

sub list_actions {
    list(['action'], map {s/::/./g; $_} Jifty->api->actions);
}

=head2 list_action_params

Takes a single parameter, $action, supplied by the dispatcher.

Shows the user all possible parameters to the action, currently in the form of a form to run that action.

=cut

sub list_action_params {
    my ($action) = action($1) or abort(404);
    Jifty::Util->require($action) or abort(404);
    $action = $action->new or abort(404);

    # XXX - Encapsulation?  Someone please think of the encapsulation!
    no warnings 'redefine';
    local *Jifty::Web::out = sub { shift; print @_ };
    local *Jifty::Action::form_field_name = sub { shift; $_[0] };
    local *Jifty::Action::register = sub { 1 };
    local *Jifty::Web::Form::Field::Unrendered::render = \&Jifty::Web::Form::Field::render;

    print start_html(-encoding => 'UTF-8', -declare_xml => 1, -title => ref($action));
    Jifty->web->form->start;
    for my $name ($action->argument_names) {
        print $action->form_field($name);
    }
    Jifty->web->form->submit( label => 'POST' );
    Jifty->web->form->end;
    print end_html;
    last_rule;
}

=head2 run_action 

Expects $1 to be the name of an action we want to run.

Runs the action, I<with the HTTP arguments as its arguments>. That is, it's not looking for Jifty-encoded (J:F) arguments.
If you have an action called "MyApp::Action::Ping" that takes a parameter, C<ip>, this action will look for an HTTP 
argument called C<ip>, (not J:F-myaction-ip).

Returns the action's result.

TODO, doc the format of the result.

On an invalid action name, throws a C<404>.
On a disallowed action mame, throws a C<403>. 
On an internal error, throws a C<500>.

=cut

sub run_action {
    my ($action_name) = action($1) or abort(404);
    Jifty::Util->require($action_name) or abort(404);
    my $action = $action_name->new or abort(404);

    Jifty->api->is_allowed( $action ) or abort(403);

    my $args = Jifty->web->request->arguments;
    delete $args->{''};

    $action->argument_values({ %$args });
    $action->validate;

    local $@;
    eval { $action->run };

    if ($@) {
        abort(500);
    }

    my $rec = $action->{record};
    if ($action->result->success && $rec and $rec->isa('Jifty::Record') and $rec->id) {
        my $url    = Jifty->web->url(path => join '/', '=', map {
            Jifty::Web->escape_uri($_)
        } 'model', ref($rec), 'id', $rec->id);
        Jifty->handler->apache->header_out('Location' => $url);
    }
    
    my $result = $action->result;

    my $out = {};
    $out->{success} = $result->success;
    $out->{message} = $result->message;
    $out->{error} = $result->error;
    $out->{field_errors} = {$result->field_errors};
    for (keys %{$out->{field_errors}}) {
        delete $out->{field_errors}->{$_} unless $out->{field_errors}->{$_};
    }
    $out->{field_warnings} = {$result->field_warnings};
    for (keys %{$out->{field_warnings}}) {
        delete $out->{field_warnings}->{$_} unless $out->{field_warnings}->{$_};
    }
    $out->{content} = $result->content;
    
    outs(undef, $out);

    last_rule;
}

1;
