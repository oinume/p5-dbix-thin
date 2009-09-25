package DBIx::Thin::Iterator::StatementHandle;

use strict;
use warnings;
use Carp qw/croak/;
use DBIx::Thin::Iterator;
use DBIx::Thin::Utils qw/check_required_args/;

use base qw/DBIx::Thin::Iterator/;

sub new {
    my ($class, %args) = @_;
    check_required_args([ qw/sth object_class/ ], \%args);
# TODO: thin required when $model->find form
    return bless {
        sth => $args{sth},
        object_class => $args{object_class}
    }, $class;
}

sub next {
    my ($self) = @_;

    my $hashref = $self->{sth}->fetchrow_hashref;
    unless ($hashref) {
        return undef;
    }

    return $self->create_object($hashref);
}

sub size {
    my $self = shift;
    return scalar $self->as_array;
}

sub group_by {
    my ($self, %args) = @_;
    $args{order} ||= 'none';
    unless (defined $args{sep}) {
        $args{sep} = '_';
    }
    check_required_args([ qw(keys order sep), ], \%args);

    if ($self->{delegate}) {
        return $self->{delegate}->group_by(%args);
    }

    my @keys = ref $args{keys} eq 'ARRAY' ? @{ $args{keys} } : ($args{keys});
    my @array = ();

    my %hash;
    if ($args{order} eq 'add') {
        Tie::IxHash->require;
        tie %hash, 'Tie::IxHash';
    }

    while (my $o = $self->next) {
        # get key from an object
        my @key_values = ();
        for my $key (@keys) {
            # set 'undef' for undef value
            push @key_values, defined $o->{$key} ? $o->{$key} : 'undef';
        }

        # genevate name like 'key1_key2_key3'
        my $key_name = join $args{sep}, @key_values;

        # grouping
        $hash{$key_name} ||= [];

        if (ref $args{callback} eq 'CODE') {
            # call 'callback' function
            $o = $args{callback}->($self, $o);
        }

        push @{ $hash{$key_name} }, $o;
        push @array, $o;
    }

    # for $iterator->as_array called twice
    $self->delegate(\@array);

    return %hash;
}

1;
