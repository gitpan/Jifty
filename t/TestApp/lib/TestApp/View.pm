package TestApp::View;
use warnings;
use strict;

use Jifty::View::Declare -base;

template 'concrete2.html' => sub {
    html {
        body {
            h1 { _( 'I have %1 concrete mixers', 2 ) };
        };
    };
};

template 'die.html' => sub {
    die "this is an error";
};

# The following templates are used to test the precedence of T::D over Mason and
# also that '/index.html' is only added to the path if the given path does not
# match.
template '/path_test/foo' => sub {
    outs('/path_test/foo - T::D');
};

template '/path_test/bar/index.html' => sub {
    outs('/path_test/bar/index.html - T::D');
};

template '/path_test/in_both' => sub {
    outs('/path_test/in_both - T::D');
};

template '/path_test/td_only' => sub {
    outs('/path_test/td_only - T::D');
};


# for testing subclasses
template 'entry.html' => sub {
    my $self = shift;
    outs("/entry.html=$self")
};

require TestApp::View::base;
require TestApp::View::instance;
import_templates TestApp::View::base under '/base';
import_templates TestApp::View::instance under '/instance';


1;
