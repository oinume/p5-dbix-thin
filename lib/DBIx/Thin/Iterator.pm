package DBIx::Thin::Iterator;

use strict;
use warnings;
use Carp qw(croak);
use UNIVERSAL::require;
use DBIx::Thin::Utils qw(check_required_args);

=head1 NAME

DBIx::Thin::Iterator - A base iteration class for DBIx::Thin

=cut

=head1 SYNOPSIS

 my $iterator = Your::Model->find_all('user', {});
 
 $iterator->size; # get row counts
 
 my $row = $iterator->first; # get first row
 
 $iterator->reset; # reset itarator potision
 
 my @rows = $iterator->as_array; # get all rows as array
 
 # iteration
 while (my $row = $iterator->next) {
     ...
 }

=cut


=head1 CLASS METHODS

=cut

=head2 new(%)

new

=cut
sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;
    $self->{current} = 0;
    $self->{_object_setup_called} = 0;
    return $self;
}

=head2 create(%)

Creates an instance of suitable DBIx::Thin::Iterator subclass.

Parameters:

 sth: DBI sth object. L<DBIx::Thin::Iterator::StatementHandle>
 data: Arrayref data. L<DBIx::Thin::Iterator::Arrayref>
 object_class: A class for each row object

=cut
sub create {
    my ($class, %args) = @_;
    my $c = undef;
    if ($args{sth}) {
        $c = 'DBIx::Thin::Iterator::StatementHandle';
    } elsif ($args{data}) {
        $c = 'DBIx::Thin::Iterator::Arrayref';
    } else {
        $c = 'DBIx::Thin::Iterator::Null';
    }
    
    $c->require or croak $@;
    return $c->new(%args);
}


=head1 INSTANCE METHODS

=cut

=head2 first

Returns the first object.

=cut

sub first { return shift->reset->next; }


=head2 next

Returns the next object.

=cut

sub next { die "Must be implemented by sub-class."; }


=head2 reset

Rest current cursor position.

=cut

sub reset {
    my $self = shift;
    $self->{current} = 0;
    return $self;
}

=head2 size

Returns containg object row num.

=cut
sub size {
    my $self = shift;
    my @rows = $self->reset->as_array;
    $self->reset;
    return scalar @rows;
}

=head2 as_array

Converts the iterator to array data.

=cut
sub as_array {
    my ($self) = @_;
    $self->reset;

    my $index = 0;
    my @array = ();
    while (my $o = $self->next) {
        $o->{__index__} = $index;
        push @array, $o;
        $index++;
    }

# TODO: what shoud i do. for __odd__
#    if ($args{set_special_number_params}) {
#        set_special_number_params(\@array);
#    }

    # for $iterator->as_array called twice
    $self->delegate(\@array);
    return @array;
}


=head2 create_object

Creates an instance for 'object_class' when L<next|DBIx::Thin::Itertor/next> is called.

=cut
sub create_object {
    my ($self, $values) = @_;

    my $class = $self->{object_class};
    unless ($class) {
        croak "Failed to create an object. Must specify argument 'object_class' at constructor";
    }

    $class->require or croak $@;
    my $object = $class->new(
        _values => $values,
        _model => $self->{model},
    );

    unless ($self->{_object_setup_called}) {
        # define accessors
        $object->setup;
        $self->{_object_setup_called} = 1;
    }

    return $object;
}


sub delegate {
    my ($self, $data) = @_;
    DBIx::Thin::Iterator::Arrayref->require or croak $@;
    $self->{delegate} = DBIx::Thin::Iterator::Arrayref->new(data => $data);
}

1;

