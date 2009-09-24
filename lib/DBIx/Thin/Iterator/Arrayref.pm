package DBIx::Thin::Iterator::Arrayref;

use strict;
use warnings;
use Carp qw/croak/;
use DBIx::Thin::Iterator;
use DBIx::Thin::Utils qw/check_required_args/;

use base qw/DBIx::Thin::Iterator/;

sub new {
    my ($class, %args) = @_;
    check_required_args([ qw/data/ ], \%args);

    unless (defined $args{thin}) {
        $args{thin} = 'DBIx::Thin';
    }
    
    my @new_data = map { $_ } @{ $args{data} };
    my $self = bless {
        thin => $args{thin},
        data => \@new_data,
        current => 0,
    }, $class;

    if (defined $args{object_class}) {
        $self->{object_class} = $args{object_class};
    }

    return $self;
}

sub next {
    my ($self) = @_;
    my $cur = $self->{current};
    if ($cur >= scalar(@{ $self->{data} })) {
        return undef;
    }

    my $tmp = $self->{data}->[$cur];
    my $object = $tmp;
    if ($self->{object_class}) {
        # If specified object_class in new, create the object.
        $object = $self->create_object($tmp);
    }

    $cur++;
    $self->{current} = $cur;

    return $object;
}

sub size { scalar @{ shift->{data} } }

sub group_by {
    my ($self, %args) = @_;
    $self->reset;
    return $self->SUPER::group_by(%args);
}

sub delegate {
    # just override to avoid loop
}

1;
