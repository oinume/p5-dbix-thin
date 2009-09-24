package DBIx::Thin::Row;

use strict;
use warnings;
use Carp qw(croak);
use DBIx::Thin::Utils qw(check_required_args);
use UNIVERSAL::require;

use base qw(DBIx::Thin::Accessor);

# TODO: implement
# key => value のデータをオブジェクトに直接保存する
# getterのアクセサをフックしてどうにかする
# 

sub new {
    my ($class, %args) = @_;
    my $self = bless { %args }, $class;
# TODO: table is needed?
    check_required_args([ qw(_table) ], \%args);

    if ($self->{_row_data}) {
        my @select_columns = keys %{ $self->{_row_data} };
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

    $self->{_get_column_cached} = {};
    $self->{_dirty_columns} = {};
}

sub _lazy_getter {
    my ($self, $col) = @_;

    return sub {
        my $self = shift;

        unless ($self->{_get_column_cached}->{$col}) {
            my $data = $self->get_column($col);
            # TODO: class check
            if ($self->can('call_inflate')) {
                $self->{_get_column_cached}->{$col} = $self->call_inflate($col, $data);
            }
        }
        $self->{_get_column_cached}->{$col};
    };
}

sub get_column {
    my ($self, $col) = @_;

    my $data = $self->{_row_data}->{$col};
    if (defined $data) {
        # TODO: class check
        if (my $method = $self->can('utf8_on')) {
            $data = $self->utf8_on($col, $data);
        }
    }

    return $data;
}

sub get_columns {
    my $self = shift;

    my %data = ();
    for my $col ( @{$self->{_select_columns}} ) {
        $data{$col} = $self->get_column($col);
    }
    return \%data;
}

sub set {
    my ($self, $args) = @_;

    for my $col (keys %$args) {
        $self->{_row_data}->{$col} = $args->{$col};
        delete $self->{_get_column_cached}->{$col};
        $self->{_dirty_columns}->{$col} = 1;
    }
}

sub get_dirty_columns {
    my $self = shift;
    my %rows = map {$_ => $self->get_column($_)}
               keys %{$self->{_dirty_columns}};
    return \%rows;
}

sub create {
    my $self = shift;
# TODO: implement find_or_create
    return $self->{_thin}->find_or_create($self->{_table}, $self->get_columns);
}

sub update {
    my ($self, $args) = @_;
    # TODO: fix API
    my $table = $self->{_table};
    $args ||= $self->get_dirty_columns;
    my $where = $self->update_or_delete_condition($table);
    $self->set($args);
    return $self->{_thin}->update(
        $table,
        data => $args,
        where => $where
    );
}

sub delete {
    my ($self, $table) = @_;
    unless ($table) {
        $table = $self->{table};
    }
    my $where = $self->update_or_delete_condition($table);
    my $primary_key = $self->{_thin}->schema_class($table)->schema_info->{primary_key};
    return $self->{_thin}->delete($table, $where->{$primary_key});
}

sub update_or_delete_condion {
    my ($self, $table) = @_;

    unless ($table) {
        croak "no table info";
    }

    my $schema = $self->{_thin}->schema_class($table);
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

1; # base code from DBIx::Skinny::Row

__END__

=head1 NAME

DBIx::Thin::Row - DBIx::Thin's Row class

=head1 METHODS

=head2 get_column

    my $val = $row->get_column($col);

get a column value from a row object.

=head2 get_columns

    my %data = $row->get_columns;

Does C<get_column>, for all column values.

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

