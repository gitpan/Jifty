package TestApp::Dispatcher;
use Jifty::Dispatcher -base;

under '/' => run {
};

on '/' => run {
    # shouldn't ever run because 02-dispatch.t doesn't request the root
    # demonstrates bad interaction between under '/' and on '/' and 
    # the condition cache in the dispatcher
    set phantom => 99;
};

before '/redirect' => run {
    Jifty->web->request->add_action(
        moniker => 'thing',
        class   => 'DoSomething',
    );
    redirect '/index.html';
};

on '/dispatch/' => run {
    dispatch "/dispatch/basic";
};

on '/dispatch/show/' => run {
    dispatch "/dispatch/basic-show";
};

my $count = 0;
my $before = 0;
my $after = 0;
my $after_once = 0;


on '/dispatch/basic' => run {
    set count => $count++;
};

on '/dispatch/basic-show' => run {
    set count => $count++;
    show '/dispatch/basic-show';
};

before '/dispatch/*' => run {
    set before     => $before++;
    set after      => $after;
    set after_once => $after_once;
};

after '/dispatch/*' => run {
    return if already_run;
    $after_once++;
};

after '/dispatch/*' => run {
    $after++;
};

on qr{/setuser/(.*)} => run {
    my $name = $1;

    my $current_user = TestApp::CurrentUser->new( name => $name );
    Jifty->web->current_user( $current_user );
    show '/index.html';
};



before '/before_stage_show' => run { show '/index.html'; };
on '/on_stage_show' => run { show '/index.html'; };
after '/after_stage_show' => run { show '/index.html'; };



before 'pre-redir-region' => run {
    redirect('/post-redir-region');

};

before '__jifty/webservices/*' => run {
    my (@actions) = grep { $_->class eq 'Jifty::Action::Redirect' } values %{ Jifty->web->request->{'actions'} };
    $_->active(0) for @actions;
};

on qr{(__jifty/webservices/.*)} => run {
    use Data::Dumper;
    for $act (@actions) {
	warn Dumper($act);
    }
};

on HTTPS '/dispatch/protocol' => run {
    set content => 'HTTPS';
};

on HTTP '/dispatch/protocol' => run {
    set content => 'NOT HTTPS';
};

on '/dispatch/protocol' => run {
    set footer => 'normal';
};

1;
