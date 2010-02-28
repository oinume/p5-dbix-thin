package DBIx::Thin::Driver::MySQL;

use strict;
use warnings;
use Carp qw(croak);

use DBIx::Thin::Utils qw(check_required_args);

use base qw(DBIx::Thin::Driver);

sub last_insert_id {
    my ($self, $sth, $opts) = @_;
    return ($sth->{mysql_insertid} || $sth->{insertid});
}

sub sql_for_unixtime { "UNIX_TIMESTAMP()" }

sub insert_ignore_available { 1 }

sub bulk_insert {
    my ($self, %args) = @_;
    my ($model, $table, $values, $ignore) =
        ($args{model}, $args{table}, $args{values}, $args{ignore});

    unless (@{ $values || [] }) {
        croak "Argument 'values' are empty";
    }

    my $schema = $model->schema_class($table, 1);
    my $inserted = 0;
    my (@columns, @bind);
    for my $value (@{ $values }) {
        # $value --> column => value hashref
        # deflate
        for my $column (keys %{ $value }) {
            $value->{$column} = $schema->call_deflate($column, $value->{$column});
        }

# TODO: check this out
        if (scalar(@columns) == 0) {
            for my $column (keys %{ $value }) {
                push @columns, $column;
            }
        }

        for my $column (keys %{$value}) {
            push @bind, $schema->utf8_off($column, $value->{$column});
        }

        $inserted++;
    }

    my $ignore_phrase = $ignore ? ' IGNORE' : '';
    my $sql = "INSERT$ignore_phrase INTO $table\n";
    $sql .= '(' . join(', ', @columns) . ')' . "\nVALUES ";

    my $values_phrase = '(' . join(', ', ('?') x @columns) . ')' . "\n";
    $sql .= join(',', ($values_phrase) x (scalar(@bind) / scalar(@columns)));

    $model->profile($sql, \@bind);
    $model->log_query($sql, \@bind);
    $self->execute_update($sql, \@bind);

    return $inserted;
}

1;
