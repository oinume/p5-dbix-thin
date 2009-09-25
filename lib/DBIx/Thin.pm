package DBIx::Thin;

use strict;
use warnings;
use Carp qw/croak/;
use File::Basename qw/basename dirname/;
use File::Spec;
use Storable ();
use UNIVERSAL::require;
use DBIx::Thin::Driver;
use DBIx::Thin::Schema;
use DBIx::Thin::Statement;
use DBIx::Thin::Utils qw/check_required_args/;

# TODO: define stringify method

our $VERSION = '0.01';

sub import {
    strict->import;
    warnings->import;
}

sub setup {
    my ($class, %args) = @_;

    my $caller = caller;
    my $driver = defined $args{driver} ?
        delete $args{driver} : DBIx::Thin::Driver->create(\%args);
    my $attributes = +{
        driver          => $driver,
        schemas         => {},
        profiler        => undef,
        profile_enabled => $ENV{DBIX_THIN_PROFILE} || 0,
        klass           => $caller,
        active_transaction => 0,
        # TODO: implement
        # as_yaml_callback => sub {}
        # as_json_callback => sub {}
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


sub load_schemas {
    my ($class, %args) = @_;
    # schema_directory must be 'lib/Your/Model' for lib/Your/Model.pm
    my $schema_directory = $args{schema_directory};
    unless (defined $schema_directory) {
        # if schema_directory is not given, we'll find it from caller module
        my $caller = caller;
        $caller =~ s!::!/!g;
        my $caller_pm = $caller . ".pm";
        my $caller_file = $INC{$caller_pm};
        unless (defined $caller_file) {
            return;
        }
        
        my $caller_base_dir = dirname($caller_file);
        my $caller_dir = basename($caller_file, ".pm");
        $schema_directory = File::Spec->catdir($caller_base_dir, $caller_dir);
    }

    my @dir_parts = File::Spec->splitdir($schema_directory);
    my $after_lib_dir = 0;
    my @required_dir_parts = ();
    for my $dir_part (@dir_parts) {
        if ($dir_part eq 'lib' || $dir_part eq 'pm') {
            $after_lib_dir = 1;
        }
        elsif ($after_lib_dir) {
            push @required_dir_parts, $dir_part;
        }
    }

    my @schemas = ();
    opendir my $dh, $schema_directory or croak "$schema_directory: $!";
    while (my $file = readdir $dh) {
        next if $file =~ /^\.{1,2}$/;
        my $schema = File::Spec->catfile(@required_dir_parts, basename($file, ".pm"));
        $schema =~ s!/!::!g;
        push @schemas, $schema;
    }
    closedir $dh;

    for my $schema (@schemas) {
        $schema->require or croak $@;
    }
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
    my ($class, $table, %args) = @_;
    check_table($table);
    check_required_args([ qw/data/ ], \%args);
    
    my $schema = $class->schema_class($table);
    my %data = %{ $args{data} };

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
#    for my $column (keys %data) {
#        # TODO: interface
#        $data{$column} = $schema->call_deflate($column, $data{$column});
#    }

    my (@columns, @bind);
    for my $column (keys %data) {
        push @columns, $column;
        push @bind, $schema->utf8_off($column, $data{$column});
    }

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

    # set auto incremented value to %data
    my $primary_key = $schema->schema_info->{primary_key};
    if ($primary_key) {
        $data{$primary_key} = $last_insert_id;
    }
    my $object = $class->create_row_object($schema, \%data);

#    $schema->call_trigger(
#        $class,
#        table => $table,
#        trigger_name => 'after_create',
#        trigger_args => $object,
#    );

    return $object;
}


sub create_by_sql {
    my ($class, %args) = @_;
    check_required_args([ qw/sql/ ], \%args);

    my $options = $args{options} || {};
    my $table = $options->{table};
    unless ($table) {
        $table = $class->get_table_insert($args{sql});
    }
    my $schema = $class->schema_class($table);

    my ($sql, $bind) = ($args{sql}, $args{bind} || []);
    $class->profile($sql, $bind);

    my $driver = $class->driver;
    my $sth = $driver->execute_update($sql, $bind);
    my $last_insert_id = $driver->last_insert_id($sth, { table => $table });
    $driver->close_sth($sth);

    my $object = $options->{fetch_created_row} ?
        $class->find_by_pk($table, $last_insert_id) : $schema->new(_table => $table);

    return $object;
}

sub create_all {
    my ($class, $table, %args) = @_;
    check_table($table);
    check_required_args([ qw/data/ ], \%args);
    
    my $driver = $class->driver;
    if (my $bulk_insert = $driver->can('bulk_insert')) {
        return $bulk_insert->($driver, $class, $table, $args{data});
    }
    else {
        croak "The driver doesn't have 'bulk_insert' method.";
    }
}

sub create_all_by_sql {
    croak "Not implemented yet.";
}


sub update {
    my ($class, $table, %args) = @_;
    check_table($table);
    check_required_args([ qw/data where/ ], \%args);
    
    my $schema = $class->schema_class($table);
#    $class->call_schema_trigger('pre_update', $schema, $table, $args);

    # deflate
#    for my $col (keys %{$args}) {
#        $args->{$col} = $schema->call_deflate($col, $args->{$col});
#    }

    my %data = %{ $args{data} };
    my (@set, @bind);
    for my $column (sort keys %data) {
        my $value = $data{$column};
        if (ref($value) eq 'SCALAR') {
            # for SCALARREF, dereference the value
            push @set, "$column = " . ${ $value };
        } else {
            push @set, "$column = ?";
            push @bind, $schema->utf8_off($column, $value);
        }
    }

    my $statement = $class->statement;
    $class->add_wheres($statement, $args{where});
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
    my ($class, %args) = @_;
    check_required_args([ qw/sql/ ], \%args);
    
    my ($sql, $bind, $options) = ($args{sql}, $args{bind}, $args{options});
    $options ||= {};
    $class->profile($sql, $bind);

# TODO: need schema?
#    my $table = $options->{table};
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

sub update_or_create {
    # TODO: implement
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
    my ($class, $table, %args) = @_;
    check_required_args([ qw/where/ ], \%args);
    
    my $schema = $class->schema_class($table);
# TODO:
#    $class->call_schema_trigger('pre_delete_all', $schema, $table, $where);

    my $statement = $class->statement;
    $statement->from([ $table ]);
    $class->add_wheres($statement, $args{where});

    my $sql = sprintf "DELETE %s", $statement->as_sql;
    my $bind = $statement->bind;
    $class->profile($sql, $bind);
    my $driver = $class->driver;
    my $sth = $driver->execute_update($sql, $bind);

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
    my ($class, $table, %args) = @_;
    return $class->find_all(
        $table,
        where => $args{where},
        options => { limit => 1 },
    )->first;
}

sub find_by_sql {
    my ($class, %args) = @_;
    check_required_args([ qw/sql/ ], \%args);
    check_select_sql($args{sql});

    my ($sql, $bind) = ($args{sql}, $args{bind} || []);
    $class->profile($sql, $bind);
    my $driver = $class->driver;
    my $sth = $driver->execute_select($sql, $bind);
    my $row = $sth->fetchrow_hashref;
    unless ($row) {
        $driver->close_sth($sth);
        return undef;
    }
    $driver->close_sth($sth);

    my $table = $args{table};
    unless (defined $table) {
        $table = $class->get_table($sql);
    }

    return $class->create_row_object($class->schema_class($table), $row);
}

sub find_by_pk {
    my ($class, $table, $pk) = @_;
    my $primary_key = $class->schema_class($table)->schema_info->{primary_key};
    return $class->find_all(
        $table,
        where => { $primary_key => $pk },
        options => { limit => 1 },
    )->first;
}

sub find_all {
    my ($class, $table, %args) = @_;
    my $where = defined $args{where} ? $args{where} : {};
    my $options = defined $args{options} ? $args{options} : {};
    
    my $schema = $class->schema_class($table);
    my $columns = $options->{select} || [ sort keys %{ $schema->schema_info->{columns} } ];
    my $statement = $class->statement;
    $statement->select($columns);
    $statement->from([ $table ]);

    %{$where} && $class->add_wheres($statement, $where);
    $options->{limit} && $statement->limit($options->{limit});
    $options->{offset} && $statement->limit($options->{offset});

    if (my $terms = $options->{order_by}) {
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

    if (my $terms = $options->{having}) {
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
    my ($class, $sql, $bind, $options) = @_;
    check_select_sql($sql);

    $class->profile($sql, $bind);
    my $sth = $class->driver->execute_select($sql, $bind);

    my $table = $options->{table};
    unless (defined $table) {
        $table = $class->get_table($sql);
    }

    DBIx::Thin::Iterator::StatementHandle->require or croak $@;
    return DBIx::Thin::Iterator::StatementHandle->new(
        thin => $class,
        sth => $sth,
        # In DBIx::Thin, object_class is a schema class.
        object_class => $class->schema_class($table),
    );
}

sub find_all_with_paginator {
    # TODO: implement
}

sub find_all_with_paginator_by_sql {
    # TODO: implement
}

sub find_or_create {
    # TODO: implement
}

sub create_row_object {
    my ($class, $object_class, $hashref) = @_;

    my %values = (
        _thin => $class,
        _table => $object_class->schema_info->{table},
        _row_data => $hashref,
    );
    my $object = $object_class->new(%values);
    $object->setup;
    
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

sub get_table_insert {
    my ($class, $sql) = @_;
    if ($sql =~ /insert\s+into\s+([\w]+)\s/i) {
        return $1;
    }
    # TODO: parse more exactly
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
    my ($class, %args) = @_;
    $args{thin} = $class;
    return DBIx::Thin::Statement->new(%args);
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

sub check_table {
    my ($table) = @_;
    unless (defined $table) {
        croak "Missing 1st argument 'table'";
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
     dsn => 'dbi:SQLite:your_project.sqlite3',
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
     defaults string_is_utf8 => 1;
     columns 
         id    => { type => Integer },
         name  => { type => String },
         email => { type => String, utf8 => 0 };
 };
 
 1;

 #-----------------------#
 # in your script
 #-----------------------#
 use Your::Model;
 
 ### insert a record
 my $row = Your::Model->create(
     'user',
     data => {
         name => 'oinume',
         email => 'oinume_at_gmail.com',
     }
 );
 
 ### select records
 my $iterator = Your::Model->find_all(
     'user',
     where => { name => 'oinume' },
     options => { limit => 20 }
 );
 while (my $row = $iterator->next) {
     ...
 }
 
 ### update records
 Your::Model->update(
     'user',
     data => { name => 'new_user' },
     where => { name => 'oinume' }
 );

 ### delete records
 Your::Model->delete_all(
     'user',
     where => { name => 'new_user' }
 );

 ### delete a record with primary key
 Your::Model->delete('user', 10);


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
