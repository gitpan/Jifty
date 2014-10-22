use strict;
use warnings;
no warnings 'utf8';
no warnings 'once';

package Jifty::Plugin::REST::Dispatcher;
use CGI qw( start_html end_html ul li a dl dt dd );
use Jifty::Dispatcher -base;
use Jifty::YAML ();
use Jifty::JSON ();
use Data::Dumper ();

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

sub list {
    my $prefix = shift;
    outs($prefix, \@_)
}

sub outs {
    my $prefix = shift;
    my $accept = ($ENV{HTTP_ACCEPT} || '');
    my $apache = Jifty->handler->apache;
    my $url    = Jifty->web->url(path => join '/', '=', map { 
        Jifty::Web->escape_uri($_)
    } @$prefix);

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
    elsif (ref($_[0]) eq 'ARRAY') {
        print start_html(-encoding => 'UTF-8', -declare_xml => 1, -title => 'models'),
              ul(map {
                li(a({-href => "$url/".Jifty::Web->escape_uri($_)}, Jifty::Web->escape($_)))
              } @{$_[0]}),
              end_html();
    }
    elsif (ref($_[0]) eq 'HASH') {
        print start_html(-encoding => 'UTF-8', -declare_xml => 1, -title => 'models'),
              dl(map {
                  dt(a({-href => "$url/".Jifty::Web->escape_uri($_)}, Jifty::Web->escape($_))),
                  dd(html_dump($_[0]->{$_})),
              } sort keys %{$_[0]}),
              end_html();
    }
    else {
        print start_html(-encoding => 'UTF-8', -declare_xml => 1, -title => 'models'),
              Jifty::Web->escape($_[0]),
              end_html();
    }

    last_rule;
}

sub html_dump {
    if (ref($_[0]) eq 'ARRAY') {
        ul(map {
            li(html_dump($_))
        } @{$_[0]});
    }
    elsif (ref($_[0]) eq 'HASH') {
        dl(map {
            dt(Jifty::Web->escape($_)),
            dd(html_dump($_[0]->{$_})),
        } sort keys %{$_[0]}),
    }
    else {
        Jifty::Web->escape($_[0]);
    }
}

sub action { resolve($_[0], 'Jifty::Action', Jifty->api->actions) }
sub model  { resolve($_[0], 'Jifty::Record', Jifty->class_loader->models) }

sub resolve {
    my $name = shift;
    my $base = shift;
    return $name if $name->isa($base);

    $name =~ s/\W+/\\W+/g;

    foreach my $cls (@_) {
        return $cls if $cls =~ /$name$/i;
    }

    abort(404);
}

sub list_models {
    list(['model'], Jifty->class_loader->models);
}

sub list_model_columns {
    my ($model) = model($1);
    outs(['model', $model], { map { $_->name => { %$_ } } $model->new->columns });
}

sub list_model_items {
    # Normalize model name - fun!
    my ($model, $column) = (model($1), $2);
    my $col = $model->new->collection_class->new;
    $col->unlimit;
    $col->columns($column);
    $col->order_by(column => $column);

    list(
        ['model', $model, $column],
        map { $_->__value($column) } @{ $col->items_array_ref || [] }
    );
}

sub show_item_field {
    my ($model, $column, $key, $field) = (model($1), $2, $3, $4);
    my $rec = $model->new;
    $rec->load_by_cols( $column => $key );
    $rec->id or abort(404);
    exists $rec->{values}{$field} or abort(404);
    outs(
        ['model', $model, $column, $key, $field],
        $rec->{values}{$field}
    );
}

sub show_item {
    my ($model, $column, $key) = (model($1), $2, $3);
    my $rec = $model->new;
    $rec->load_by_cols( $column => $key );
    $rec->id or abort(404);
    outs(
        ['model', $model, $column, $key],
        $rec->{values}
    );
}

sub replace_item {
    die "hey replace item";
}

sub delete_item {
    die "hey delete item";
}

sub list_actions {
    list(['action'], Jifty->api->actions);
}

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

sub run_action {
    my ($action) = action($1) or abort(404);
    Jifty::Util->require($action) or abort(404);
    $action = $action->new or abort(404);

    # Jifty->api->is_allowed( $action ) or abort(403);

    my $args = Jifty->web->request->arguments;
    delete $args->{''};

    $action->argument_values({ %$args });
    $action->validate;

    local $@;
    eval { $action->run };

    if ($@ or $action->result->failure) {
        abort(500);
    }

    my $rec = $action->{record};
    if ($rec and $rec->isa('Jifty::Record') and $rec->id) {
        my $url    = Jifty->web->url(path => join '/', '=', map {
            Jifty::Web->escape_uri($_)
        } 'model', ref($rec), 'id', $rec->id);
        Jifty->handler->apache->header_out('Location' => $url);
    }

    print start_html(-encoding => 'UTF-8', -declare_xml => 1, -title => 'models'),
          ul(map { li(html_dump($_)) } $action->result->message, Jifty->web->response->messages),
          end_html();

    last_rule;
}

1;
