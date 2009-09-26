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

    for my $alias (@{ $self->{_select_columns} }) {
        (my $col = lc $alias) =~ s/.+\.(.+)/$1/o;
        next if $class->can($col);
        
        no strict 'refs';
        no warnings 'redefine';
        *{"$class\::$col"} = $self->_lazy_getter($col);
    }

    $self->{_get_value_cached} = {};
    $self->{_dirty_columns} = {};
}

sub _lazy_getter {
    my ($self, $col) = @_;

    return sub {
        my $self = shift;

        unless ($self->{_get_value_cached}->{$col}) {
            my $value = $self->get_value($col);
            # TODO: class check
            if ($self->can('call_inflate')) {
                $self->{_get_value_cached}->{$col} = $self->call_inflate($col, $value);
            }
        }
        $self->{_get_value_cached}->{$col};
    };
}

sub get_value {
    my ($self, $column) = @_;

    my $value = $self->{_values}->{$column};
    unless (defined $value) {
        return $value;
    }

    # TODO: class check
    if (my $method = $self->can('utf8_on')) {
        $value = $self->utf8_on($column, $value);
    }

    return $value;
}

sub get_values {
    my $self = shift;
    my %values = ();
    for my $col ( @{$self->{_select_columns}} ) {
        $values{$col} = $self->get_value($col);
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
    my ($self, $args) = @_;

    for my $col (keys %$args) {
        $self->{_values}->{$col} = $args->{$col};
        delete $self->{_get_value_cached}->{$col};
        $self->{_dirty_columns}->{$col} = 1;
    }
}

sub get_dirty_columns {
    my $self = shift;
    my %rows = map {$_ => $self->get_value($_)}
               keys %{$self->{_dirty_columns}};
    return \%rows;
}

sub create {
    my $self = shift;
# TODO: implement find_or_create
    return $self->{_model}->find_or_create($self->{_table}, $self->get_values);
}

sub update {
    my ($self, $data) = @_;
    my $table = $self->get_table;
    $data ||= $self->get_dirty_columns;
    my $where = $self->update_or_delete_condition($table);
    $self->set($data);
    return $self->{_model}->update(
        $table,
        data => $data,
        where => $where
    );
}

sub delete {
    my ($self) = @_;
    my $table = $self->get_table;
    my $where = $self->update_or_delete_condition($table);
    my $primary_key = $self->schema_info->{primary_key};
    return $self->{_model}->delete($table, $where->{$primary_key});
}

sub update_or_delete_condion {
    my ($self, $table) = @_;

    unless ($table) {
        croak "no table info";
    }

    my $schema = $self->{_model}->schema_class($table);
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

sub get_table {
    my ($self) = @_;
    unless ($self->can('schema_info')) {
        croak "Cannot call method 'schema_info' of '@{[ __PACKAGE__ ]}'";
    }
    my $table = $self->schema_info->{table};
    return $table;
}

1; # base code from DBIx::Skinny::Row

__END__

=head1 NAME

DBIx::Thin::Row - DBIx::Thin's Row class

=head1 METHODS

=head2 get_value

    my $val = $row->get_value($col);

get a column value from a row object.

=head2 get_values

    my %data = $row->get_values;

Does C<get_value>, for all column values.

=head2 set

    $row->set({$col => $val});

set columns data.

=head2 get_dirty_columns

returns those that have been changed.

=head2 insert

insert row data. call find_or_create method.

=head2 updat

update is executed for instance record.

It works by schema in which primary key exists.

=head2 delete

delete is executed for instance record.

It works by schema in which primary key exists.

