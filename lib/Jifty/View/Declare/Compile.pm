package Jifty::View::Declare::Compile;
use strict;
use base 'B::Deparse';
use B qw(class main_root main_start main_cv svref_2object opnumber perlstring
	 OPf_WANT OPf_WANT_VOID OPf_WANT_SCALAR OPf_WANT_LIST
	 OPf_KIDS OPf_REF OPf_STACKED OPf_SPECIAL OPf_MOD
	 OPpLVAL_INTRO OPpOUR_INTRO OPpENTERSUB_AMPER OPpSLICE OPpCONST_BARE
	 OPpTRANS_SQUASH OPpTRANS_DELETE OPpTRANS_COMPLEMENT OPpTARGET_MY
	 OPpCONST_ARYBASE OPpEXISTS_SUB OPpSORT_NUMERIC OPpSORT_INTEGER
	 OPpSORT_REVERSE OPpSORT_INPLACE OPpSORT_DESCEND OPpITER_REVERSED
	 SVf_IOK SVf_NOK SVf_ROK SVf_POK SVpad_OUR SVf_FAKE SVs_RMG SVs_SMG
         CVf_METHOD CVf_LOCKED CVf_LVALUE CVf_ASSERTION
	 PMf_KEEP PMf_GLOBAL PMf_CONTINUE PMf_EVAL PMf_ONCE PMf_SKIPWHITE
	 PMf_MULTILINE PMf_SINGLELINE PMf_FOLD PMf_EXTENDED);

BEGIN {
    die "You need a custom version of B::Deparse from http://svn.jifty.org/svn/jifty.org/B/"
        unless B::Deparse->can('e_method')
}

=head1 NAME

Jifty::View::Declare::Compile - Compile Jifty templates into JavaScript

=head1 DESCRIPTION

B<EXPERIMENTAL:> This code is currently under development and experimental. You will need to get the version of the L<B::Deparse> package from the Subversion repository at:

  http://svn.jifty.org/svn/jifty.org/B/

in order to use this class.

This is a subclass of L<B::Deparse> that compiles Perl into JavaScript with the intention of allowing Jifty applications to render L<Template::Declare> templates on the client.

This class does the dirty work of translating a Perl code reference in JavaScript. 

See L<Jifty::Web::PageRegion/client_cache_content>.

=head1 METHODS

=head2 is_scope

See L<B::Deparse>.

=cut

sub is_scope { goto \&B::Deparse::is_scope }

=head2 is_state

See L<B::Deparse>

=cut

sub is_state { goto \&B::Deparse::is_state }

=head2 null

See L<B::Deparse>

=cut

sub null { goto \&B::Deparse::null }

=head2 padname

=cut

sub padname {
    my $self = shift;
    my $targ = shift;
    return substr($self->padname_sv($targ)->PVX, 1);
}

require CGI;
our %TAGS = (
    map { $_ => +{} }
        map {@{$_||[]}} @CGI::EXPORT_TAGS{qw/:html2 :html3 :html4 :netscape :form/}
);

=head2 deparse

=cut

sub deparse {
    my $self = shift;
    my $ret = $self->SUPER::deparse(@_);
    return '' if $ret =~ m/use (strict|warnings)/;
    return $ret;
}

=head2 loop_common

=cut

sub loop_common {
    my $self = shift;
    my($op, $cx, $init) = @_;
    my $enter = $op->first;
    my $kid = $enter->sibling;
    if ($enter->name eq "enteriter") { # foreach
	my $ary = $enter->first->sibling; # first was pushmark
	my $var = $ary->sibling;

	if ($ary->name eq 'null' and $enter->private & OPpITER_REVERSED) {
	    # "reverse" was optimised away
	    return $self->SUPER::loop_common(@_);
	} elsif ($enter->flags & OPf_STACKED
	    and not null $ary->first->sibling->sibling)
	{
	    return $self->SUPER::loop_common(@_);
	} else {
	    $ary = $self->deparse($ary, 1);
	}

	if (null $var) {
	    if ($enter->flags & OPf_SPECIAL) { # thread special var
		$var = $self->pp_threadsv($enter, 1);
	    } else { # regular my() variable
		$var = $self->padname($enter->targ);
	    }
	} elsif ($var->name eq "rv2gv") {
	    $var = $self->pp_rv2sv($var, 1);
	    if ($enter->private & OPpOUR_INTRO) {
		# our declarations don't have package names
		$var =~ s/^(.).*::/$1/;
		$var = "our $var";
	    }
	} elsif ($var->name eq "gv") {
	    $var = $self->deparse($var, 1);
	    $var = '$' . $var if $var eq '_';
	}
	else {
	    return $self->SUPER::loop_common(@_);
	}


	my $body = $kid->first->first->sibling; # skip OP_AND and OP_ITER
	# statement() foreach (@foo);
	if (!is_state $body->first and $body->first->name ne "stub") {
	    Carp::confess unless $var eq '$_';
	    $body = $body->first;
	    return "$ary.each(function (\$_) {".$self->deparse($body, 2)."} )";
	}
	# XXX not handling cont block here yet
	return "$ary.each(function ($var) {".$self->deparse($body, 0)."} )";
    }
    return $self->SUPER::loop_common(@_);
}

=head2 maybe_my

=cut

sub maybe_my {
    my $self = shift;
    my($op, $cx, $text) = @_;
    if ($op->private & OPpLVAL_INTRO and not $self->{'avoid_local'}{$$op}) {
	if (B::Deparse::want_scalar($op)) {
	    return "var $text";
	} else {
	    return $self->maybe_parens_func("my", $text, $cx, 16);
	}
    } else {
	return $text;
    }
}

=head2 maybe_parens_func

=cut

sub maybe_parens_func {
    my $self = shift;
    my($func, $text, $cx, $prec) = @_;
    return "$func($text)";

}

=head2 const

=cut

sub const {
    my $self = shift;
    my($sv, $cx) = @_;
    if (class($sv) eq "NULL") {
       return 'null';
    }
    return $self->SUPER::const(@_);
}

=head2 pp_undef

=cut

sub pp_undef { 'null' }

=head2 pp_sne

=cut

sub pp_sne { shift->binop(@_, "!=", 14) }

=head2 pp_grepwhile

=cut

sub pp_grepwhile { shift->mapop(@_, "grep") }

=head2 mapop

=cut

sub mapop {
    my $self = shift;
    my($op, $cx, $name) = @_;
    return $self->SUPER::mapop(@_) unless $name eq 'grep';
    my($expr, @exprs);
    my $kid = $op->first; # this is the (map|grep)start
    $kid = $kid->first->sibling; # skip a pushmark
    my $code = $kid->first; # skip a null
    if (is_scope $code) {
	$code = "{" . $self->deparse($code, 0) . "} ";
    } else {
	$code = $self->deparse($code, 24) . ", ";
    }
    $kid = $kid->sibling;
    for (; !null($kid); $kid = $kid->sibling) {
	$expr = $self->deparse($kid, 6);
	push @exprs, $expr if defined $expr;
    }
    return "(".join(", ", @exprs).").select(function (\$_) $code)";
}

=head2 e_anoncode

=cut

sub e_anoncode {
    my ($self, $info) = @_;
    my $text = $self->deparse_sub($info->{code});
    return "function () " . $text;
}

=head2 e_anonhash

=cut

sub e_anonhash {
    my ($self, $info) = @_;
    my @exprs = @{$info->{exprs}};
    my @pairs;
    while (my @p = splice(@exprs, 0, 2)) {
	push @pairs, join(': ', map { $self->deparse($_, 6) } @p);
    }
    return '{' . join(", ", @pairs) . '}';
}

=head2 pp_entersub

=cut

sub pp_entersub {
    my $self = shift;
    my $ret = $self->SUPER::pp_entersub(@_);
    $ret =~ s/return\s*\((.*)\)/return [$1]/ if $ret =~ m/^attr/;

    return $ret;
}

=head2 e_method

=cut

sub e_method {
    my ($self, $info) = @_;
    my $obj = $info->{object};
    if ($obj->name eq 'const') {
        $obj = $self->const_sv($obj)->PV;
    }
    else {
        $obj = $self->deparse($obj, 24);
    }

    my $meth = $info->{method};
    $meth = $self->deparse($meth, 1) if $info->{variable_method};
    my $args = join(", ", map { $self->deparse($_, 6) } @{$info->{args}} );
    my $kid = $obj . "." . $meth;
    return $kid . "(" . $args . ")"; # parens mandatory
}

=head2 walk_linesq

=cut

sub walk_lineseq {
    my ($self, $op, $kids, $callback) = @_;
    my $xcallback = $callback;
    if ((!$op || $op->next->name eq 'grepwhile') && $kids->[-1]->name ne 'return') {
	$callback = sub { my ($expr, $index) = @_;
			  $expr = "return ($expr)" if $index == $#{$kids};
			  $xcallback->($expr, $index) };
    }
    $self->SUPER::walk_lineseq($op, $kids, $callback);
}

=head2 compile_to_js

=cut

sub compile_to_js {
    my $class = shift;
    my $code = shift;
    return 'function() '.$class->new->coderef2text($code);
}

=head1 SEE ALSO

L<B::Deparse>, L<Jifty::Web::PageRegion/client_cache_content>

=cut

1;
