use warnings;
use strict;

=head1 NAME

Jifty::Filter::DateTime -- A Jifty::DBI filter to work with
                          Jifty::DateTime objects

=head1 SYNOPSIS

   # use it with Jifty::DBI::Filter::Date or J::D::F::DateTime
    column created =>
      type is 'timestamp',
      filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::DateTime),
      label is 'Created',
      is immutable;

=head1 DESCRIPTION

Jifty::Filter::DateTime promotes DateTime objects to Jifty::DateTime
objects on load. This has the side effect of setting their time zone
based on the record's current user's preferred time zone, when
available.

This is intended to be combined with C<Jifty::DBI::Filter::Date> or
C<Jifty::DBI::Filter::DateTime>, e.g.

    column created =>
      type is 'timestamp',
      filters are qw( Jifty::Filter::DateTime Jifty::DBI::Filter::DateTime),
      label is 'Created',
      is immutable;

=cut

package Jifty::Filter::DateTime;
use base qw(Jifty::DBI::Filter);


=head2 decode

If the value is a DateTime, replace it with a Jifty::DateTime
representing the same time, setting the time zone in the process.

=cut


sub decode {
    my $self = shift;
    my $value_ref = $self->value_ref;

    return unless ref($$value_ref) && $$value_ref->isa('DateTime');

    # XXX There has to be a better way to do this
    my %args;
    for (qw(year month day hour minute second nanosecond time_zone formatter)) {
        $args{$_} = $$value_ref->$_ if(defined($$value_ref->$_));
    }

    # we want this DateTime's TZ to be in the current user's TZ, unless
    # it represents a date
    $args{_replace_time_zone} = 1
        unless $args{time_zone} =~ /floating/i;

    my $dt = Jifty::DateTime->new(%args);

    $$value_ref = $dt;
}

=head1 SEE ALSO

L<Jifty::DBI::Filter::Date>, L<Jifty::DBI::Filter::DateTime>,
L<Jifty::DateTime>

=head1 LICENSE

Jifty is Copyright 2005-2007 Best Practical Solutions, LLC.
Jifty is distributed under the same terms as Perl itself.

=cut

1;
