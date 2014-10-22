use warnings;
use strict;

package Jifty::Everything;

=head1 NAME

Jifty::Everything - Load all of the important Jifty modules at once.

=cut

use Jifty ();
use Jifty::Dispatcher ();
use Jifty::Object ();
use Jifty::Config ();
use Jifty::Handle ();
use Jifty::ClassLoader ();
use Jifty::Util ();

use Jifty::Record ();
use Jifty::Collection ();
use Jifty::Action ();
use Jifty::Action::Record ();
use Jifty::Action::Record::Create ();
use Jifty::Action::Record::Update ();
use Jifty::Action::Record::Delete ();


use Jifty::Continuation ();

use Jifty::LetMe ();

use Jifty::Logger ();
use Jifty::Handler ();
use Jifty::Handler::Static ();
use Jifty::MasonHandler ();

use Jifty::Model::Schema ();



use Jifty::Request ();
use Jifty::Request::Mapper ();
use Jifty::Result ();
use Jifty::Response ();
use Jifty::CurrentUser ();

# We can _not_ load Server.pm unless we're in a Server context because
# HTTP::Server::Simple::Mason bastardizes HTML::Mason::FakeApache::send_http_header
# with hook::lexwrap
#use Jifty::Server;

use Jifty::Web ();
use Jifty::Web::Session ();
use Jifty::Web::PageRegion ();
use Jifty::Web::Form ();
use Jifty::Web::Form::Clickable ();
use Jifty::Web::Form::Element ();
use Jifty::Web::Form::Link ();
use Jifty::Web::Form::Field ();
use Jifty::Web::Menu ();

use Module::Pluggable;
Module::Pluggable->import(search_path => ['Jifty::Web::Form::Field'], require => 1);
__PACKAGE__->plugins;

1;
