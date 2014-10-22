use warnings;
use strict;

package Jifty::DateTime;

=head1 NAME

Jifty::DateTime - a DateTime subclass that knows about Jifty users


=head1 DESCRIPTION

Jifty natively stores timestamps in the database in GMT.  Dates are stored
without timezone. This class loads and parses dates and sets them
into the proper timezone.

=cut

BEGIN {
    # we spent about 30% of the time in validate during 'require
    # DateTime::Locale' which isn't necessary at all
    require Params::Validate;
    no warnings 'redefine';
    local *Params::Validate::validate = sub { pop @_, return @_ };
    require DateTime::Locale;
}

use base qw(Jifty::Object DateTime);


=head2 new ARGS

See L<DateTime/new>.  After calling that method, set this object's
timezone to the current user's time zone, if the current user has a
method called C<time_zone>.

=cut

sub new {
    my $class = shift;
    my %args  = (@_);
    my $self  = $class->SUPER::new(%args);

    # Unless the user has explicitly said they want a floating time,
    # we want to convert to the end-user's timezone.  This is
    # complicated by the fact that DateTime auto-appends
    if (!$args{time_zone} and my $tz = $self->current_user_has_timezone) {
        $self->set_time_zone("UTC");
        $self->set_time_zone( $tz );
    }
    return $self;
}

=head2 current_user_has_timezone

Return timezone if the current user has it

=cut

sub current_user_has_timezone {
    my $self = shift;
    $self->_get_current_user();
    return unless $self->current_user->can('user_object');
    my $user_obj = $self->current_user->user_object or return;
    my $f = $user_obj->can('time_zone') or return;
    return $f->($user_obj);
}

=head2 new_from_string STRING

Take some user defined string like "tomorrow" and turn it into a
C<Jifty::Datetime> object.  If the string appears to be a _date_, keep
it in the floating timezone, otherwise, set it to the current user's
timezone.

=cut

sub new_from_string {
    my $class  = shift;
    my $string = shift;
    my $now;

    {
        # Date::Manip interprets days of the week (eg, ''monday'') as
        # days within the *current* week. Detect these and prepend
        # ``next''
        # XXX TODO: Find a real solution (better date-parsing library?)
        if($string =~ /^\s* (?:monday|tuesday|wednesday|thursday|friday|saturday|sunday)$/xi) {
            $string = "next $string";
        }
        
        # Why are we parsing this as GMT? This feels really wrong.  It will get the wrong answer
        # if the current user is in another tz.
        require Date::Manip;
        Date::Manip::Date_Init("TZ=GMT");
        $now = Date::Manip::UnixDate( $string, "%o" );
    }
    return undef unless $now;
    my $self = $class->from_epoch( epoch => $now, time_zone => 'gmt' );
    if (my $tz = $self->current_user_has_timezone) {
        $self->set_time_zone("floating")
            unless ( $self->hour or $self->minute or $self->second );
        $self->set_time_zone( $tz );
    }
    return $self;
}

=head2 friendly_date

Returns the date given by this C<Jifty::DateTime> object. It will display "today"
for today, "tomorrow" for tomorrow, or "yesterday" for yesterday. Any other date
will be displayed in ymd format.

=cut

sub friendly_date {
    my $self = shift;
    my $ymd = $self->ymd;

    my $rel = DateTime->now(time_zone => $self->time_zone);
    if ($ymd eq $rel->ymd) {
        return "today";
    }
    
    $rel->subtract(days => 1);
    if ($ymd eq $rel->ymd) {
        return "yesterday";
    }
    
    $rel->add(days => 2);
    if ($ymd eq $rel->ymd) {
        return "tomorrow";
    }
    
    return $ymd;
}

1;
