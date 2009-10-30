package DBIx::Thin::Driver::MySQL;

use strict;
use warnings;

use DBIx::Thin::Utils qw(check_required_args);

use base qw(DBIx::Thin::Driver);

sub last_insert_id {
    my ($self, $sth, $opts) = @_;
    return ($sth->{mysql_insertid} || $sth->{insertid});
}

sub sql_for_unixtime {
    return "UNIX_TIMESTAMP()";
}

sub bulk_insert {
    # TODO: implement
    my ($self, $thin, $table, $args) = @_;

    my $schema = $thin->schema_class($table);
    my $inserted = 0;
    my (@columns, @bind);
    for my $arg (@{$args}) {
        # deflate
        for my $column (keys %{$arg}) {
# TODO:
            # $arg->{$column} = $schema->call_deflate($column, $arg->{$column});
            $arg->{$column} = $schema->call_deflate($column, $arg->{$column});
        }

        if (scalar(@columns) == 0) {
            for my $column (keys %{$arg}) {
                push @columns, $column;
            }
        }

        for my $column (keys %{$arg}) {
# TODO: utf8_off
            push @bind, $schema->utf8_off($column, $arg->{$column});
        }
        $inserted++;
    }

    my $sql = "INSERT INTO $table\n";
    $sql .= '(' . join(', ', @columns) . ')' . "\nVALUES ";

    my $values = '(' . join(', ', ('?') x @columns) . ')' . "\n";
    $sql .= join(',', ($values) x (scalar(@bind) / scalar(@columns)));

    $thin->profile($sql, \@bind);
    $self->execute_update($sql, \@bind);

    return $inserted;
}

1;
