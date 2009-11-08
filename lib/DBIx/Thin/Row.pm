package DBIx::Thin::Row;

use strict;
use warnings;
use Carp qw(croak);
use DBIx::Thin::Utils qw(check_required_args);
use UNIVERSAL::require;

use base qw(DBIx::Thin::Accessor);

# TODO: implement
# FETCH,STOREを実装するか？


sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;
# TODO: implement other tables
#    check_required_args([ qw(other_tables) ], \%args);
    $self->check_methods();

    if ($self->{_values}) {
        my @select_columns = keys %{ $self->{_values} };
        if (@select_columns) {
            $self->{_select_columns} = \@select_columns;
        }
    }

    return $self;
}

sub setup {
    my $self = shift;
    my $class = ref $self;
    $self->check_methods();

    for my $alias (@{ $self->{_select_columns} }) {
        (my $column = lc $alias) =~ s/.+\.(.+)/$1/o;
        next if $class->can($column);
        
        no strict 'refs';
        no warnings 'redefine';
        *{"$class\::$column"} = $self->_lazy_accessor($column);
    }

    $self->{_get_value_cached} = {};
    $self->{_dirty_columns} = {};

    return $self;
}

sub check_methods {
    my ($self) = @_;
    for my $method (qw(utf8_on force_utf8_on call_inflate)) {
        unless ($self->can($method)) {
            my $class = ref $self;
            croak "Method '$method' is not defined on '$class'";
        }
    }
}

sub _lazy_accessor {
    my ($self, $column) = @_;

    return sub {
        my ($self, $new_value) = @_;

        if (defined ($new_value)) {
            # setter
            $self->set($column => $new_value);
        } else {
            # getter
            unless ($self->{_get_value_cached}->{$column}) {
                my $value = $self->get_value($column);
                # TODO: test
                $self->{_get_value_cached}->{$column} = $self->call_inflate($column, $value);
                my $code = $self->get_extra_inflate_code($column);
                if (defined $code) {
                    $self->{_get_value_cached}->{$column} = $code->($column, $value);
                }
            }

            return $self->{_get_value_cached}->{$column};
        }
    };
}

sub get_value {
    my ($self, $column) = @_;

    my $value = $self->{_values}->{$column};
    unless (defined $value) {
        return $value;
    }

    $value = $self->utf8_on($column, $value);
    if ($self->is_extra_utf8_column($column)) {
        # TODO: write test
        $value = $self->force_utf8_on($column, $value);
    }

    return $value;
}

sub get_values {
    my $self = shift;
    my %values = ();
    for my $column ( @{$self->{_select_columns}} ) {
        $values{$column} = $self->get_value($column);
    }
    return %values;
}

sub get_raw_value {
    my ($self, $column) = @_;
    return $self->{_values}->{$column};
}

sub get_raw_values {
    my ($self) = @_;
    my %values = ();
    while (my ($k, $v) = each %{ $self->{_values} || {} }) {
        $values{$k} = $v;
    }
    return %values;
}

sub set {
    my ($self, %args) = @_;

    for my $column (keys %args) {
        $self->{_values}->{$column} = $args{$column};
        delete $self->{_get_value_cached}->{$column};
        $self->{_dirty_columns}->{$column} = 1;
    }
}

sub is_extra_utf8_column {
    my ($self, $column) = @_;
    my @utf8 = @{ $self->{_utf8} || [] };
    return grep { $_ eq $column } @utf8 ? 1 : 0;
}

sub get_extra_inflate_code {
    my ($self, $column) = @_;
    my $inflate = $self->{_inflate} || {};
    return $inflate->{$column};
}

sub get_dirty_columns {
    my $self = shift;
    my %rows = map { $_ => $self->get_value($_) } keys %{$self->{_dirty_columns}};
    return %rows;
}

sub create {
    my $self = shift;
# TODO: implement find_or_create
    return $self->model->find_or_create($self->table, $self->get_values);
}

sub update {
    my ($self, %values) = @_;
    my $table = $self->table;

    my %dirty = $self->get_dirty_columns;
    while (my ($k, $v) = each %dirty) {
        next if (defined $values{$k});
        $values{$k} = $dirty{$k};
    }

    unless (keys %values) {
        return 0;
    }

    my $where = $self->update_or_delete_condition($table);
    $self->set(%values);
    return $self->model->update(
        $table,
        values => \%values,
        where => $where
    );
}

sub delete {
    my ($self) = @_;
    my $table = $self->table;
    my $where = $self->update_or_delete_condition($table);
    my $primary_key = $self->schema_info->{primary_key};
    return $self->model->delete($table, $where->{$primary_key});
}

sub update_or_delete_condition {
    my ($self, $table) = @_;

    unless ($table) {
        croak "no table info";
    }

    my $schema = $self->model->schema_class($table);
    unless ($schema) {
        croak "Unknown table: $table";
    }

    # get target table primary_key
    my $primary_key = $schema->schema_info->{primary_key};
    unless ($primary_key) {
        croak "$table hs no primary key.";
    }

    unless (grep { $primary_key eq $_ } @{ $self->{_select_columns} }) {
        croak "can't get primary column in your query.";
    }

    return { $primary_key => $self->$primary_key };
}

sub table {
    my ($self) = @_;
    unless ($self->can('schema_info')) {
        croak "Cannot call method 'schema_info' of '@{[ __PACKAGE__ ]}'";
    }
    my $table = $self->schema_info->{table};
    return $table;
}

sub model { shift->{_model} }

1; # base code from DBIx::Skinny::Row

__END__


=head1 NAME

DBIx::Thin::Row - DBIx::Thin's Row class


=head1 SYNOPSIS

  my $user = Your::Model->find_by_pk('user', 1);
  # $user is an instance of sub-class of DBIx::Thin::Row
  print 'id: ', $user->id, "\n";
  print 'name: ', $user->name, "\n";


=head1 ACCESSORS

DBIx::Thin::Row generates accessors for selected columns.


=head1 METHODS

=head2 get_value($column)

Get a column value from a row object without inflating.

EXAMPLE

  my $id = $row->get_value('id');


=head2 get_values()

Does C<get_value>, for all column values.

  my %data = $row->get_values;


=head2 set(%values)

set columns data.

  $row->set($column => $value);



=head2 get_dirty_columns()

Returns those that have been changed.


=head2 create

insert row data. call find_or_create method.


=head2 update

update is executed for instance record.

It works by schema in which primary key exists.


=head2 delete

delete is executed for instance record.

It works by schema in which primary key exists.

