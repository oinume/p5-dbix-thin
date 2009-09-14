package DBIx::Thin;

use strict;
use warnings;
use Carp qw/croak/;
use DBI;
use Storable ();
use UNIVERSAL::require;
use DBIx::Thin::Driver;
use DBIx::Thin::Statement;
use DBIx::Thin::Utils qw/check_required_args/;
use DBIx::Thin::Driver;

our $VERSION = '0.01';

sub import {
    strict->import;
    warnings->import;
}

sub setup {
    my ($class, $args) = @_;
    my %args = %{ $args || {} };

    my $caller = caller;
    my $driver = defined $args{driver} ?
        delete $args{driver} : DBIx::Thin::Driver->create(\%args);
#    use Data::Dumper;
#    die Dumper $driver;;
    my $attributes = +{
        driver          => $driver,
        schemas         => {},
        profiler        => undef,
        profile_enabled => $ENV{DBIX_THIN_PROFILE} || 0,
        klass           => $caller,
        active_transaction => 0,
    };

    {
        no strict 'refs';
        *{"$caller\::attributes"} = sub { ref $_[0] ? $_[0] : $attributes };

        my @not_define = qw/__ANON__ BEGIN VERSION/;
        my %symbols = %DBIx::Thin::;
        my @functions = ();
        for my $name (keys %symbols) {
            next if (grep { $name eq $_ } @not_define);
            push @functions, $name;
        }

        for my $f (@functions) {
            *{"$caller\::$f"} = \&$f;
        }
    }
}

sub load_schema {
    my ($class, $args) = @_;
    my $caller = caller;
    $caller =~ s!::!/!g;
    my $caller_pm = $caller . ".pm";
    if ($INC{$caller_pm}) {
        # TODO: dir
    }
=pod

kazuhiro@geneva % perl -MData::Dumper -e 'print Dumper \%INC'
$VAR1 = {
          'warnings/register.pm' => '/usr/share/perl/5.10/warnings/register.pm',
          'bytes.pm' => '/usr/share/perl/5.10/bytes.pm',
          'XSLoader.pm' => '/usr/lib/perl/5.10/XSLoader.pm',
          'Carp.pm' => '/usr/share/perl/5.10/Carp.pm',
          'Exporter.pm' => '/usr/share/perl/5.10/Exporter.pm',
          'warnings.pm' => '/usr/share/perl/5.10/warnings.pm',
          'overload.pm' => '/usr/share/perl/5.10/overload.pm',
          'Data/Dumper.pm' => '/usr/lib/perl/5.10/Data/Dumper.pm'
        };

=cut
}

sub new {
    my ($class, $connection_info) = @_;
    my $attr = $class->attributes;

    my $driver   = delete $attr->{driver};
    my $profiler = delete $attr->{profiler};
    
    my $self = bless Storable::dclone($attr), $class;
    my $driver_clone = $driver->clone;
    if ($connection_info) {
        $driver_clone->connection_info($connection_info);
        $driver_clone->reconnect;
        # TODO: test
    }

    $self->attributes->{driver} = $driver_clone;
    $self->attributes->{profiler} = $profiler;

    return $self;
}

sub schema_class {
    my ($class, $table) = @_;
    my $schema = $class->attributes->{schemas}->{$table};
    unless ($schema) {
        DBIx::Thin::Schema->require or croak $@;
        $schema = DBIx::Thin::Schema::table2schema_class($table);
        unless ($schema) {
            # TODO: test here
            $schema = 'DBIx::Thin::Row';
        }
        $class->attributes->{schemas}->{$table} = $schema;
        $schema->require or croak $@;
    }

    return $schema;
}

sub profiler {
    my ($class) = @_;

    my $attr = $class->attributes;
    if ($attr->{profiler}) {
        return $attr->{profiler};
    }

    DBIx::Thin::Profiler->require or croak $@;
    $attr->{profiler} = DBIx::Thin::Profiler->new;
    return $attr->{profiler};
}

sub profile {
    my ($class, $sql, $bind) = @_;
    my $attr = $class->attributes;
    if ($attr->{profile_enabled} && $sql) {
        $class->profiler->record_query($sql, $bind);
    }
}

sub driver { shift->attributes->{driver} }

########################################
# ORM update methods
########################################
sub create {
    my ($class, $table, $values) = @_;
    unless (defined $table) {
        croak "Missing 1st argument 'table'";
    }

    my $schema = $class->schema_class($table);
    my %values = %{ $values || {} };

    # call trigger
#    $class->call_schema_trigger('before_create', $schema, $table, $args);
# TODO:
#    $schema->call_trigger(
#        $class,
#        table => $table,
#        trigger_name => 'before_create',
#        trigger_args => $values,
#    );
    
    # deflate
#    for my $column (keys %values) {
#        # TODO: interface
#        $values{$column} = $schema->call_deflate($column, $values{$column});
#    }

    my (@columns, @bind);
    for my $column (keys %values) {
        push @columns, $column;
        push @bind, $schema->utf8_off($column, $values{$column});
    }

    # TODO: INSERT or REPLACE. bind_param_attributes etc...
    chop(my $placeholder = ('?,' x @columns));
    my $sql = sprintf(
        "INSERT INTO %s\n (%s)\n VALUES(%s)",
        $table,
        join(', ', @columns),
        $placeholder,
    );
    $class->profile($sql, \@bind);

    my $driver = $class->driver;
    my $sth = $driver->execute_update($sql, \@bind);
    my $last_insert_id = $driver->last_insert_id($sth, { table => $table });
    $driver->close_sth($sth);

    # set auto incremented value to %values
    my $pk = $schema->schema_info->{primary_key};
    if ($pk) {
        $values{$pk} = $last_insert_id;
    }
    my $object = $class->create_row_object($schema, \%values);

#    $schema->call_trigger(
#        $class,
#        table => $table,
#        trigger_name => 'after_create',
#        trigger_args => $object,
#    );

    return $object;
}


sub create_by_sql {
    my ($class, $table, $args) = @_;

    unless (defined $table) {
        croak "Missing 1st argument 'table'";
    }

    my $schema = $class->schema_class($table);

    # call trigger
# TODO:
#    $schema->call_trigger(
#        $class,
#        table => $table,
#        trigger_name => 'before_create',
#        trigger_args => \%values,
#    );
    
    # deflate
#    for my $column (keys %values) {
#        # TODO: interface
#        $values{$column} = $schema->call_deflate($column, $values{$column});
#    }

# TODO: utf8_off
#    my (@columns, @bind);
#    for my $column (keys %args) {
#        push @columns, $column;
#        push @bind, $schema->utf8_off($column, $values{$column});
#    }

    my ($sql, @bind) = ($args->{sql}, @{ $args->{bind} || []});
    $class->profile($sql, \@bind);

    my $driver = $class->driver;
    my $sth = $driver->execute_update($sql, \@bind);
    my $last_insert_id = $driver->last_insert_id($sth, { table => $table });
    $driver->close_sth($sth);

    my $object = $schema->new;
    if ($args->{fetch_inserted_row}) {
        $object = $class->find_by_pk($table, $last_insert_id);
    }

# TODO:
#    $schema->call_trigger(
#        $class,
#        table => $table,
#        trigger_name => 'after_create',
#        trigger_args => $object,
#    );

    return $object;
}

sub create_all {
    my ($class, $table, $values) = @_;
    my $driver = $class->driver;
    my $bulk_insert = $driver->can('bulk_insert');
    return $bulk_insert->($driver, $class, $table, $values);
}

sub create_all_by_sql {
    croak "Not implemented yet.";
}


sub update {
    my ($class, $table, $args, $where) = @_;

    my $schema = $class->schema_class($table);
#    $class->call_schema_trigger('pre_update', $schema, $table, $args);

    # deflate
#    for my $col (keys %{$args}) {
#        $args->{$col} = $schema->call_deflate($col, $args->{$col});
#    }

    my (@set, @bind);
    for my $column (sort keys %{ $args }) {
        my $value = $args->{$column};
        if (ref($value) eq 'SCALAR') {
            # for SCALARREF, dereference the value
            push @set, "$column = " . ${ $value };
        } else {
            push @set, "$column = ?";
            push @bind, $value;
# TODO:
#            push @bind, $schema->utf8_off($column, $value);
        }
    }

    my $statement = $class->statement;
    $class->add_wheres($statement, $where);
    push @bind, @{ $statement->bind };

    my $sql = "UPDATE $table SET " . join(', ', @set) . ' ' . $statement->as_sql_where;
    $class->profile($sql, \@bind);

    my $driver = $class->driver;
    my $sth = $driver->execute_update($sql, \@bind);
    my $rows = $sth->rows;
# TODO:
#    $class->call_schema_trigger('post_update', $schema, $table, $rows);
    $driver->close_sth($sth);

    return $rows;
}

sub update_by_sql {
    my ($class, $sql, $bind, $opts) = @_;
    $class->profile($sql, $bind);

# TODO: schema使う？
#    my $table = $opts->{table};
#    unless (defined $table) {
#        if ($sql =~ /^update\s+([\w]+)\s/i) {
#            $table = $1;
#        }
#    }
#    my $schema = $class->schema_class($table);

    my $driver = $class->driver;
    my $sth = $driver->execute_update($sql, $bind);
    my $updated = $sth->rows;
    $driver->close_sth($sth);

    return $updated;
}

sub delete {
    my ($class, $table, $primary_key_value) = @_;
    my $schema = $class->schema_class($table);
# TODO:
#    $class->call_schema_trigger('pre_delete', $schema, $table, $primary_key_value);

    my $pk = $schema->schema_info->{primary_key};
    my $statement = $class->statement;
    $statement->from([ $table ]);
    $class->add_wheres($statement, { $pk => $primary_key_value });
    
    my $sql = "DELETE " . $statement->as_sql;
    my $bind = $statement->bind;
    $class->profile($sql, $bind);
    my $driver = $class->driver;
    my $sth = $driver->execute_update($sql, $bind);

#    $class->call_schema_trigger('post_delete', $schema, $table);

    my $deleted = $sth->rows;
    $driver->close_sth($sth);
    
    return $deleted;
}

sub delete_all {
    my ($class, $table, $where) = @_;
    my $schema = $class->schema_class($table);
# TODO:
#    $class->call_schema_trigger('pre_delete_all', $schema, $table, $where);

    my $statement = $class->statement;
    $statement->from([ $table ]);
    $class->add_wheres($statement, $where);

    my $sql = sprintf "DELETE %s", $statement->as_sql;
    $class->profile($sql, $statement->bind);
    my $driver = $class->driver;
    my $sth = $driver->execute_update($sql, $statement->bind);

#    $class->call_schema_trigger('post_delete_all', $schema, $table);

    my $deleted = $sth->rows;
    $driver->close_sth($sth);

    return $deleted;
}


sub delete_by_sql {
    my ($class, $sql, $bind) = @_;

    $class->profile($sql, $bind);
    my $driver = $class->driver;
    my $sth = $driver->execute_update($sql, $bind);
#    $class->call_schema_trigger('post_delete_by_sql', $schema, $table);
    my $deleted = $sth->rows;
    $driver->close_sth($sth);
    
    return $deleted;
}


########################################
# ORM select methods
########################################
sub find {
    my ($class, $table, $where, $opts) = @_;
    $opts ||= {};
    $opts->{limit} = 1;
    return $class->find_all($table, $where, $opts)->first;
}

sub find_by_sql {
    my ($class, $sql, $bind, $opts) = @_;
    check_select_sql($sql);

    $class->profile($sql, $bind);
    my $driver = $class->driver;
    my $sth = $driver->execute_select($sql, $bind);
    my $row = $sth->fetchrow_hashref;
    unless ($row) {
        $driver->close_sth($sth);
        return undef;
    }
    $driver->close_sth($sth);

    my $table = $opts->{table};
    unless (defined $table) {
        $table = $class->get_table($sql);
    }

    return $class->create_row_object($class->schema_class($table), $row);
}

sub find_by_pk {
    my ($class, $table, $pk, $opts) = @_;
    $opts ||= {};
    $opts->{limit} = 1;
    my $primary_key = $class->schema_class($table)->schema_info->{primary_key};
    return $class->find_all($table, { $primary_key => $pk }, $opts)->first;
}

sub find_all {
    my ($class, $table, $where, $opts) = @_;

    my $schema = $class->schema_class($table);
    my $columns = $opts->{select} || $schema->schema_info->{columns};
    my $statement = $class->statement;
    $statement->select($columns);
    $statement->from([ $table ]);

    $where && $class->add_wheres($statement, $where);
    $opts->{limit} && $statement->limit($opts->{limit});
    $opts->{offset} && $statement->limit($opts->{offset});

    if (my $terms = $opts->{order_by}) {
        unless (ref($terms) eq 'ARRAY') {
            $terms = [ $terms ];
        }

        my @orders = ();
        for my $term (@{ $terms }) {
            my ($column, $case);
            if (ref($term) eq 'HASH') {
                ($column, $case) = each %{ $term };
            } else {
                $column = $term;
                $case = 'ASC';
            }
            push @orders, { column => $column, desc => $case };
        }
        $statement->order(\@orders);
    }

    if (my $terms = $opts->{having}) {
        for my $column (keys %{ $terms }) {
            $statement->add_having($column => $terms->{$column});
        }
    }

    return $class->find_all_by_sql(
        $statement->as_sql,
        $statement->bind,
        { table => $table },
    );
}

sub find_all_by_sql {
    my ($class, $sql, $bind, $opts) = @_;
    check_select_sql($sql);

    $class->profile($sql, $bind);
    my $sth = $class->driver->execute_select($sql, $bind);

    my $table = $opts->{table};
    unless (defined $table) {
        $table = $class->get_table($sql);
    }

    DBIx::Thin::Iterator::StatementHandle->require or croak $@;
    return DBIx::Thin::Iterator::StatementHandle->new(
        sth => $sth,
        object_class => $class->schema_class($table), # In DBIx::Thin, row_class is a schema.
    );
}

sub find_all_with_paginator {
    # TODO: implement
}

sub find_all_with_paginator_by_sql {
    # TODO: implement
}

sub create_row_object {
    my ($class, $object_class, $hashref) = @_;

    my %values = %{ $hashref || {} };
    my $object = $object_class->new(%values);
    # Define accessors
    ref($object)->mk_accessors(keys %values);

    return $object;
}

sub get_table {
    my ($class, $sql) = @_;
    # TODO: parse SQL
    if ($sql =~ /^.+from\s+([\w]+)\s/i) {
        return $1;
    }
    croak "Failed to extract table name from SQL\n$sql";
}

sub check_select_sql {
    my ($sql) = @_;
    unless ($sql =~ /^[\s\(]*select/i) {
        croak "SQL must be start with 'SELECT'.";
    }
}

sub _camelize {
    my $s = shift;
    join('', map{ ucfirst $_ } split(/(?<=[A-Za-z])_(?=[A-Za-z])|\b/, $s));
}


sub placeholder {
    my $class = shift;
    chop(my $s = ('?,' x @_));
    return $s;
}


sub statement {
    my ($class, $args) = @_;
    $args->{thin} = $class;
    return DBIx::Thin::Statement->new($args);
}


sub call_schema_trigger {
    my ($class, $trigger, $schema, $table, $args) = @_;
    $schema->call_trigger($class, $table, $trigger, $args);
}


sub add_wheres {
    my ($class, $statement, $wheres) = @_;
    for my $column (keys %{ $wheres }) {
        $statement->add_where($column => $wheres->{$column});
    }
}


1;

__END__

=head1 NAME

DBIx::Thin - Lightweight ORMapper

=cut

=head1 SYNOPSIS

 ### Your/Model.pm
 package Your::Model;
 use DBIx::Thin;
 DBIx::Thin->setup(
     dsn => 'dbi:SQLite:',
     username => '',
     password => '',
 );
 1;

 ### Your/Model/User.pm
 package Your::Model::User;
 use DBIx::Thin::Schema;
 use base qw/DBIx::Thin::Row/;
 
 install_table 'user' => schema {
     primary_key 'id',
     columns qw/id name email/,
 };
 
 1;
 
 ### in your script:
 use Your::Model;
 
 # insert a record
 my $row = Your::Model->create(
     'user',
     {
         name => 'oinume',
         email => 'oinume_at_gmail.com',
     }
 );
 
 ### select records
 my $iterator = Your::Model->find_all(
     'user',
     { name => 'oinume' },
 );
 while (my $row = $iterator->next) {
     ...
 }
 
 ### update records
 Your::Model->update(
     'user',
     # data
     { name => 'new_user' },
     # where
     { name => 'oinume' }
 );

 ### delete records
 Your::Model->delete_all(
     'user',
     # where
     { name => 'new_user' }
 );
 
=head1 AUTHOR

Kazuhiro Oinuma C<< <oinume __at__ gmail.com> >>

=head1 THANKS

DBIx::Thin is based on L<DBIx::Skinny>'s code.
thanks for nekokak.

=cut

=head1 REPOSITORY

  git clone git://github.com/oinume/p5-dbix-thin.git

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2009, Kazuhiro Oinuma C<< <oinume __at__ gmail.com> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

=cut
