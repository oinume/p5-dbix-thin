package DBIx::Thin;

use strict;
use warnings;
use Carp qw(croak);
use Storable ();
use UNIVERSAL::require;
use DBIx::Thin::Driver;
use DBIx::Thin::Schema;
use DBIx::Thin::Utils qw(check_required_args);

our $VERSION = '0.07';

sub import {
    my ($class, %args) = @_;
    strict->import;
    warnings->import;
    {
        no strict 'refs';
        my $caller = caller;
        *{"$caller\::inflate_code"} = \&DBIx::Thin::Schema::inflate_code;
    }

    if (defined $args{setup}) {
        if (ref $args{setup} ne 'HASH') {
            croak "'setup' option must be hashref. (use DBIx::Thin setup => {...})";
        }
        $class->setup(%{ $args{setup} });
    }

    if ($args{load_defined_schemas}) {
        $class->load_defined_schemas();
    }
}

sub query_logger {
    my ($sql, $bind) = @_;
    my $bind_str = '';
    if (defined $bind && @{ $bind }) {
        for my $v (@{ $bind }) {
            $bind_str .= (defined $v) ? "'$v', " : "undef, ";
        }
        chop $bind_str;
        chop $bind_str;
    }

    my $log = <<"...";
@@@@@ SQL @@@@@
$sql
@@@@@ BIND @@@@
$bind_str
...

    warn "$log\n";
}

sub setup {
    my ($class, %args) = @_;

    my $caller = caller;
    if ($caller eq 'DBIx::Thin') {
        $caller = caller 1;
    }

    my $driver = defined $args{driver} ?
        delete $args{driver} : DBIx::Thin::Driver->create(%args);

    my $attributes = +{
        driver          => $driver,
        schemas         => {},
        profiler        => undef,
        profile_enabled => $ENV{DBIX_THIN_PROFILE} || 0,
        query_logger    => defined $ENV{DBIX_THIN_QUERY_LOG} ? \&query_logger : undef,
        klass           => $caller,
        active_transaction => 0,
        # TODO: implement
        # as_yaml_callback => sub {}
        # as_json_callback => sub {}
    };

    {
        no strict 'refs';
        *{"$caller\::attributes"} = sub { ref $_[0] ? $_[0] : $attributes };

        my @not_define = qw(__ANON__ BEGIN VERSION);
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


sub load_defined_schemas {
    my ($class, %args) = @_;
    File::Basename->require or croak $@;
    File::Spec->require or croak $@;
    
    # schema_directory must be 'lib/Your/Model' for lib/Your/Model.pm
    my $schema_directory = $args{schema_directory};
    unless (defined $schema_directory) {
        # if schema_directory is not given, we'll find it from caller module
        my $caller = caller;
        if ($caller eq 'DBIx::Thin') {
            $caller = caller 1;
        }
        $caller =~ s!::!/!g;
        my $caller_pm = $caller . ".pm";
        my $caller_file = $INC{$caller_pm};
        unless (defined $caller_file) {
            return;
        }
        
        my $caller_base_dir = File::Basename::dirname($caller_file);
        my $caller_dir = File::Basename::basename($caller_file, ".pm");
        $schema_directory = File::Spec->catdir($caller_base_dir, $caller_dir);
    }

    my @dir_parts = File::Spec->splitdir($schema_directory);
    my $after_lib_dir = 0;
    my @required_dir_parts = ();
    for my $dir_part (@dir_parts) {
        if ($dir_part eq 'lib' || $dir_part eq 'pm') {
            $after_lib_dir = 1;
        } elsif ($after_lib_dir) {
            push @required_dir_parts, $dir_part;
        }
    }

    my @schemas = ();
    opendir my $dh, $schema_directory or croak "$schema_directory: $!";
    while (my $file = readdir $dh) {
        next if $file =~ /^\.{1,2}$/;
        next if $file !~ /\.pm$/;

        my $schema = File::Spec->catfile(
            @required_dir_parts,
            File::Basename::basename($file, ".pm")
        );
        $schema =~ s!/!::!g;
        push @schemas, $schema;
    }
    closedir $dh;

    for my $schema (@schemas) {
        $schema->require or croak $@;
    }
}

sub new {
    my ($class, %args) = @_;
    my $attr = $class->attributes;

    my $driver   = delete $attr->{driver};
    my $profiler = delete $attr->{profiler};
    my $query_logger = delete $attr->{query_logger};

    my $self = bless Storable::dclone($attr), $class;
    my $driver_clone = undef;
    if (keys %args) {
        # If connection_info given, we must re-create a Driver's instance
        # becase dsn would be changed (e.g mysql -> SQLite)
        $driver_clone = DBIx::Thin::Driver->create(%args);
        $driver_clone->reconnect;
    }
    else {
        $driver_clone = $driver->clone;
    }

    $self->attributes->{driver} = $driver_clone;
    $self->attributes->{profiler} = $profiler;
    $self->attributes->{query_logger} = $query_logger;

    # get deleted attributes back
    $attr->{driver} = $driver;
    $attr->{profiler} = $profiler;
    $attr->{query_logger} = $query_logger;

    return $self;
}

sub schema_class {
    my ($class, $table, $die_when_not_found) = @_;
    unless (defined $die_when_not_found) {
        $die_when_not_found = 0;
    }

    my $schema = $class->attributes->{schemas}->{$table};
    unless (ref $schema) {
        $schema = DBIx::Thin::Schema::table2schema_class($table);
        unless ($schema) {
            if ($die_when_not_found) {
                croak "Can't find a schema class for '$table'";
            }
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
        warn $class->profiler->record_query($sql, $bind) . "\n";
    }
}

sub log_query {
    my ($class, $sql, $bind) = @_;
    if (my $logger = $class->attributes->{query_logger}) {
        $logger->($sql, $bind);
    }
}

sub driver { shift->attributes->{driver} }

sub execute_select { shift->driver->execute_select(@_) }

sub execute_update { shift->driver->execute_update(@_) }


########################################
# ORM select methods
########################################
sub find_by_pk {
    my ($class, $table, $pk) = @_;
    my $primary_key = $class->schema_class($table, 1)->schema_info->{primary_key};
    return $class->search(
        $table,
        where => { $primary_key => $pk },
        limit => 1,
    )->first;
}


sub find {
    my ($class, $table, %args) = @_;
    return $class->search(
        $table,
        where => $args{where},
        limit => 1,
        options => $args{options} || {},
    )->first;
}

sub find_by_sql {
    my ($class, %args) = @_;
    check_required_args([ qw(sql) ], \%args);
    check_select_sql($args{sql});

    my ($sql, $bind, $options) = ($args{sql}, $args{bind} || [], $args{options} || {});
    $class->profile($sql, $bind); # TODO: refactoring
    $class->log_query($sql, $bind);

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

    return $class->create_row_object(
        object_class => $class->schema_class($table),
        row_data => $row,
        options => $options
    );
}


sub search {
    my ($class, $table, %args) = @_;
    my $schema = $class->schema_class($table, 1);
    my %columns = %{ $schema->schema_info->{columns} };
    my @select = defined $args{select} ? @{ $args{select} } : sort keys %columns;
    my $where = defined $args{where} ? $args{where} : {};
    my $limit = defined $args{limit} ? $args{limit} : undef;
    my $offset = defined $args{offset} ? $args{offset} : undef;
    my $options = defined $args{options} ? $args{options} : {};

    my $statement = $class->statement;
    my %by_sql_options = (table => $table);
    $class->add_select(
        statement => $statement,
        schema => $schema,
        select => \@select,
        columns => \%columns,
        by_sql_options => \%by_sql_options,
    );
    $statement->from([ $table ]);

    %{$where} && $class->add_wheres(statement => $statement, wheres => $where);
    if (defined $limit) {
        $statement->limit($limit);
    }
    if (defined $offset) {
        $statement->offset($offset);
    }

    $class->add_order_by(
        statement => $statement,
        order_by => $args{order_by},
    );

    # TODO: group_by

    $class->add_having(
        statement => $statement,
        having => $args{having},
    );

    $class->set_utf8_option(
        options => $options,
        by_sql_options => \%by_sql_options,
    );

    $class->set_inflate_option(
        options => $options,
        by_sql_options => \%by_sql_options,
    );

    return $class->search_by_sql(
        sql => $statement->as_sql,
        bind => $statement->bind,
        options => \%by_sql_options,
    );
}


sub search_by_sql {
    my ($class, %args) = @_;
    check_required_args([ qw(sql) ], \%args);
    check_select_sql($args{sql});

    my ($sql, $bind, $options) = ($args{sql}, $args{bind} || [], $args{options} || {});
    $class->profile($sql, $bind); # TODO: refactoring
    $class->log_query($sql, $bind);

    my $sth = $class->driver->execute_select($sql, $bind);

    my $table = $options->{table};
    unless (defined $table) {
        $table = $class->get_table($sql);
    }

    DBIx::Thin::Iterator::StatementHandle->require or croak $@;
    my %extra_args = ();
    my $utf8 = $options->{utf8};
    if (defined $utf8) {
         (ref $utf8 ne 'ARRAY') && croak "options 'utf8' must be ARRAYREF";
        $extra_args{utf8} = $utf8;
    }
    my $inflate = $options->{inflate};
    if (defined $inflate) {
        (ref $inflate ne 'HASH') && croak "options 'inflate' must be HASHREF";
        $extra_args{inflate} = $inflate;
    }

    my $iterator = DBIx::Thin::Iterator::StatementHandle->new(
        sth => $sth,
        # In DBIx::Thin, object_class is a schema class.
        object_class => $class->schema_class($table),
        # Used for $row->update or $row->delete.
        model => $class,
        %extra_args,
    );

    return wantarray ? $iterator->as_array : $iterator;
}

sub search_with_pager {
    my ($class, $table, %args) = @_;
    my $schema = $class->schema_class($table, 1);
    my %columns = %{ $schema->schema_info->{columns} };
    my @select = defined $args{select} ? @{ $args{select} } : sort keys %columns;
    my $where = defined $args{where} ? $args{where} : {};
    my $limit = defined $args{limit} ? $args{limit} : undef;
    my $offset = defined $args{offset} ? $args{offset} : undef;
    my $options = defined $args{options} ? $args{options} : {};

    my $statement = $class->statement;
    my %by_sql_options = (table => $table);
    $class->add_select(
        statement => $statement,
        schema => $schema,
        select => \@select,
        columns => \%columns,
        by_sql_options => \%by_sql_options,
    );
    $statement->from([ $table ]);

    %{$where} && $class->add_wheres(statement => $statement, wheres => $where);
    if (defined $limit) {
        $statement->limit($limit);
    }
    if (defined $offset) {
        $statement->offset($offset);
    }

    $class->add_order_by(
        statement => $statement,
        order_by => $args{order_by},
    );

    # TODO: group_by

    $class->add_having(
        statement => $statement,
        having => $args{having},
    );

    $class->set_utf8_option(
        options => $options,
        by_sql_options => \%by_sql_options,
    );

    $class->set_inflate_option(
        options => $options,
        by_sql_options => \%by_sql_options,
    );

    my $statement_for_count = Storable::dclone($statement);
    $statement_for_count->select([ 'COUNT(*)' ]);

    return $class->search_with_pager_by_sql(
        sql => $statement->as_sql,
        bind => $statement->bind,
        sql_for_count => $statement_for_count->as_sql,
        bind_for_count => $statement_for_count->bind,
        page => $args{page},
        entries_per_page => $args{entries_per_page},
        options => \%by_sql_options,
    );
}

sub search_with_pager_by_sql {
    my ($class, %args) = @_;
    check_required_args([ qw(sql) ], \%args);
    check_select_sql($args{sql});

    my ($sql, $bind, $options) = ($args{sql}, $args{bind} || [], $args{options} || {});
    my $page = $args{page};
    my $entries_per_page = $args{entries_per_page};

    my $sql_for_count = '';
    my @bind_for_count = ();
    if (defined $args{sql_for_count}) {
        $sql_for_count = $args{sql_for_count};
        @bind_for_count =
            (defined $args{bind_for_count}) ? @{ $args{bind_for_count} } : @{ $bind };
    } else {
        # Generate counting sql by parsing given 'sql'
        if ($sql =~ /^\s*SELECT.+?\s+FROM\s+(.+)$/is) {
            $sql_for_count = "SELECT count(*) FROM $1";
            $sql_for_count =~ s/ORDER\s+BY([^\)]+?)$//i;
            @bind_for_count = @{ $bind };
        } else {
            croak "'sql' must be the form 'SELECT ... FROM ...' (Maybe failed to parse given SQL)";
        }
    }

    # Get total entry count at first
    $class->profile($sql_for_count, \@bind_for_count); # TODO: refactoring
    $class->log_query($sql_for_count, \@bind_for_count);

    my $sth = $class->driver->execute_select($sql_for_count, \@bind_for_count);
    my $total_entries = $sth->fetchrow_array();
    $sth->finish();

    # If 'page' exceeds the max, set the last page to current.
    DBIx::Thin::Pager->require or croak $@;
    my (undef, $entries_per_page2, $current_page, undef) =
        DBIx::Thin::Pager->validate_pager_data(
            total_entries    => $total_entries,
            entries_per_page => $entries_per_page,
            current_page     => $page,
        );

    if ($total_entries == 0) {
        # If no entries, returns a null pager and an iterator
        DBIx::Thin::Iterator::Null->require or croak $@;
        my $pager = DBIx::Thin::Pager->new(
            total_entries    => $total_entries,
            entries_per_page => $entries_per_page2,
            current_page     => $current_page,
        );
        return ($pager, DBIx::Thin::Iterator::Null->new);
    }

    if ($entries_per_page2 > 0) {
        # TODO: this is MySQL notation. we must adapt to other DBs.
        $sql .= " LIMIT $entries_per_page2";
        $sql .= " OFFSET " . ($current_page - 1) * $entries_per_page2;
    }

    $class->profile($sql, $bind);
    $class->log_query($sql, $bind);

    $sth = $class->driver->execute_select($sql, $bind);

    my $table = $options->{table};
    unless (defined $table) {
        $table = $class->get_table($sql);
    }

    my %extra_args = ();
    my $utf8 = $options->{utf8};
    if (defined $utf8) {
         (ref $utf8 ne 'ARRAY') && croak "options 'utf8' must be ARRAYREF";
        $extra_args{utf8} = $utf8;
    }
    my $inflate = $options->{inflate};
    if (defined $inflate) {
        (ref $inflate ne 'HASH') && croak "options 'inflate' must be HASHREF";
        $extra_args{inflate} = $inflate;
    }

    my $pager = DBIx::Thin::Pager->new(
        total_entries    => $total_entries,
        entries_per_page => $entries_per_page2,
        current_page     => $current_page,
    );

    DBIx::Thin::Iterator::StatementHandle->require or croak $@;
    my $iterator = DBIx::Thin::Iterator::StatementHandle->new(
        sth => $sth,
        # In DBIx::Thin, object_class is a schema class.
        object_class => $class->schema_class($table),
        # Used for $row->update or $row->delete.
        model => $class,
        %extra_args,
    );

# TODO: make the API?
#    $iterator->{_pager} = $pager;
    return ($pager, $iterator);
}


# TODO: POD
sub count {
    my ($class, %args) = @_;
    # TODO: implement
    croak "Not implemented yet.";
}

# TODO: POD
sub count_by_sql {
    my ($class, %args) = @_;
    check_required_args([ qw(sql) ], \%args);
    check_select_sql($args{sql});

    my ($sql, $bind, $options) = ($args{sql}, $args{bind} || [], $args{options} || {});
    $class->profile($sql, $bind);
    $class->log_query($sql, $bind);

    my $sth = $class->driver->execute_select($sql, $bind);

    my @columns = $sth->fetchrow_array();
    $sth->finish();

    return (@columns) ? $columns[0] : 0;
}


sub find_or_create {
    # TODO: implement
    croak "Not implemented yet.";
}


########################################
# ORM update methods
########################################
sub create {
    my ($class, $table, %args) = @_;
    check_table($table);
    check_required_args([ qw(values) ], \%args);
    
    my $schema = $class->schema_class($table, 1);
    my %values = %{ $args{values} };

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
    for my $column (keys %values) {
        $values{$column} = $schema->call_deflate($column, $values{$column});
    }

    my (@columns, @bind);
    for my $column (keys %values) {
        push @columns, $column;
        push @bind, $schema->utf8_off($column, $values{$column});
    }

    my $driver = $class->driver;
    my $placeholder = $class->placeholder(@columns);
    my $sql = sprintf(
        "INSERT %sINTO %s\n (%s)\n VALUES (%s)",
        ($driver->insert_ignore_available && $args{ignore}) ? 'IGNORE ' : '',
        $table,
        join(', ', @columns),
        $placeholder,
    );
    $class->profile($sql, \@bind);
    $class->log_query($sql, \@bind);

    my $sth = $driver->execute_update($sql, \@bind);
    my $last_insert_id = $driver->last_insert_id($sth, { table => $table });
    $driver->close_sth($sth);

    # set auto incremented value to %values
    my $primary_key = $schema->schema_info->{primary_key};
    if ($primary_key) {
        $values{$primary_key} = $last_insert_id;
    }
    my $object = $class->create_row_object(
        object_class => $schema,
        row_data => \%values,
    );

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
    check_required_args([ qw(sql) ], \%args);

    my $options = $args{options} || {};
    my $table = $options->{table};
    unless ($table) {
        $table = $class->get_table_insert($args{sql});
    }
    my $schema = $class->schema_class($table);

    my ($sql, $bind) = ($args{sql}, $args{bind} || []);
    $class->profile($sql, $bind);
    $class->log_query($sql, $bind);

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
    check_required_args([ qw(values) ], \%args);
    
    my $driver = $class->driver;
    if (my $bulk_insert = $driver->can('bulk_insert')) {
        return $bulk_insert->(
            $driver,
            model => $class,
            table => $table,
            values => $args{values},
            ignore => $args{ignore},
        );
    }
    else {
        croak "The driver doesn't have 'bulk_insert' method.";
    }
}

sub update {
    my ($class, $table, %args) = @_;
    check_table($table);
    check_required_args([ qw(values where) ], \%args);
    
    my $schema = $class->schema_class($table);
#    $class->call_schema_trigger('pre_update', $schema, $table, $args);

    my %values = %{ $args{values} };
    # deflate
    for my $column (keys %values) {
        $values{$column} = $schema->call_deflate($column, $values{$column});
    }

    my (@set, @bind);
    for my $column (sort keys %values) {
        my $value = $values{$column};
        if (ref($value) eq 'SCALAR') {
            # for SCALARREF, dereference the value
            push @set, "$column = " . ${ $value };
        } else {
            push @set, "$column = ?";
            push @bind, $schema->utf8_off($column, $value);
        }
    }

    my $statement = $class->statement;
    $class->add_wheres(
        statement => $statement,
        wheres => $args{where}
    );
    push @bind, @{ $statement->bind };

    my $sql = "UPDATE $table SET " . join(', ', @set) . ' ' . $statement->as_sql_where;
    $class->profile($sql, \@bind);
    $class->log_query($sql, \@bind);

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
    check_required_args([ qw(sql) ], \%args);
    
    my ($sql, $bind, $options) = ($args{sql}, $args{bind}, $args{options});
    $options ||= {};
    $class->profile($sql, $bind);
    $class->log_query($sql, $bind);

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


sub delete_by_pk {
    my ($class, $table, $primary_key_value) = @_;
    my $schema = $class->schema_class($table, 1);
# TODO:
#    $class->call_schema_trigger('pre_delete', $schema, $table, $primary_key_value);

    my $pk = $schema->schema_info->{primary_key};
    my $statement = $class->statement;
    $statement->from([ $table ]);
    $class->add_wheres(
        statement => $statement,
        wheres => { $pk => $primary_key_value }
    );
    
    my $sql = "DELETE " . $statement->as_sql;
    my $bind = $statement->bind;
    $class->profile($sql, $bind);
    $class->log_query($sql, $bind);
    my $driver = $class->driver;
    my $sth = $driver->execute_update($sql, $bind);

#    $class->call_schema_trigger('post_delete', $schema, $table);

    my $deleted = $sth->rows;
    $driver->close_sth($sth);
    
    return $deleted;
}

sub delete {
    my ($class, $table, %args) = @_;
    check_required_args([ qw(where) ], \%args);
    
    my $schema = $class->schema_class($table, 1);
# TODO:
#    $class->call_schema_trigger('pre_delete', $schema, $table, $where);

    my $statement = $class->statement;
    $statement->from([ $table ]);
    $class->add_wheres(
        statement => $statement,
        wheres => $args{where}
    );

    my $sql = sprintf "DELETE %s", $statement->as_sql;
    my $bind = $statement->bind;
    $class->profile($sql, $bind);
    $class->log_query($sql, $bind);
    my $driver = $class->driver;
    my $sth = $driver->execute_update($sql, $bind);

#    $class->call_schema_trigger('post_delete', $schema, $table);

    my $deleted = $sth->rows;
    $driver->close_sth($sth);

    return $deleted;
}


sub delete_by_sql {
    my ($class, %args) = @_;
    check_required_args([ qw(sql) ], \%args);

    my ($sql, $bind, $options) = ($args{sql}, $args{bind}, $args{options});
    $options ||= {};
    $class->profile($sql, $bind);
    $class->log_query($sql, $bind);
    my $driver = $class->driver;
    my $sth = $driver->execute_update($sql, $bind);
    my $deleted = $sth->rows;
    $driver->close_sth($sth);
    
    return $deleted;
}


sub create_row_object {
    my ($class, %args) = @_;
    my ($object_class, $row_data, $options) =
        ($args{object_class}, $args{row_data}, $args{options});
    $options ||= {};

    my %new_args = (
        _values => $row_data,
        _model => $class,
    );
    while (my ($k, $v) = each %{ $options }) {
        $new_args{$k} = $v;
    }

    $object_class->require or croak $@;
    return $object_class->new(%new_args)->setup;
}

sub get_table {
    my ($class, $sql) = @_;
    # TODO: parse SQL properly
    if ($sql =~ /^.+from\s+([\w]+)\s*/i) {
        return $1;
    }
    croak "Failed to extract table name from SQL\n$sql";
}

sub get_table_insert {
    my ($class, $sql) = @_;
    if ($sql =~ /insert\s+into\s+([\w]+)\s*/i) {
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
#    $args{thin} = $class;
    DBIx::Thin::Statement->require or croak $@;
    return DBIx::Thin::Statement->new(%args);
}


sub add_select {
    my ($class, %args) = @_;
    my $statement = $args{statement};
    my $schema = $args{schema};
    my @select = @{ $args{select} };
    my %columns = %{ $args{columns} };
    my $by_sql_options = $args{by_sql_options};

    unless (@select) {
        croak "No 'select' columns";
    }

    for my $s (@select) {
        if (ref $s eq 'HASH') {
            # for aliases like:
            # select => [ { id => 'my_id' }, { name => 'my_name' }, ... ]
            my @keys = keys %{ $s };
            my ($column, $alias) = ($keys[0], $s->{$keys[0]});
            unless (@keys) {
                croak "Invalid 'select' attribute form (No hashref keys)";
            }
            $statement->add_select($column, $alias);

            if ($columns{$column}) {
                if ($schema->is_utf8_column($column)) {
                    # enable utf8 for aliases
                    $by_sql_options->{utf8} ||= [];
                    push @{ $by_sql_options->{utf8} }, $alias;
                }
                if (defined $columns{$column}->{inflate}) {
                    # inflate aliases
                    $by_sql_options->{inflate} ||= {};
                    $by_sql_options->{inflate}->{$alias} = $columns{$column}->{inflate};
                }
            }
        } else {
            # for normal style like: select => [ 'id', 'name', ... ]
            $statement->add_select($s, $s);
        }
    }
}


sub add_having {
    my ($class, %args) = @_;
    unless (defined $args{having}) {
        return;
    }

    my $statement = $args{statement};
    my $having = defined $args{having} ? $args{having} : {};
    # TODO: test
    for my $column (keys %{ $having }) {
        $statement->add_having($column => $having->{$column});
    }
}

sub set_utf8_option {
    my ($class, %args) = @_;
    my ($options, $by_sql_options) = ($args{options}, $args{by_sql_options });
    unless (defined $options->{utf8}) {
        return;
    }

    unless (ref $options->{utf8} eq 'ARRAY') {
        croak "options 'utf8' must be ARRAYREF";
    }
    $by_sql_options->{utf8} ||= [];
    push @{ $by_sql_options->{utf8} }, @{ $options->{utf8} };
}


sub set_inflate_option {
    my ($class, %args) = @_;
    my ($options, $by_sql_options) = ($args{options}, $args{by_sql_options });
    unless (defined $options->{inflate}) {
        return;
    }

    unless (ref $options->{inflate} eq 'HASH') {
        croak "options 'utf8' must be HASHREF";
    }
    $by_sql_options->{inflate} ||= {};
    while (my ($k, $v) = each %{ $options->{inflate} }) {
        $by_sql_options->{inflate}->{$k} = $v;
    }
}


sub call_schema_trigger {
    my ($class, $trigger, $schema, $table, $args) = @_;
    $schema->call_trigger($class, $table, $trigger, $args);
}


sub add_wheres {
    my ($class, %args) = @_;
    my ($statement, $wheres) = ($args{statement}, $args{wheres});
    for my $column (keys %{ $wheres }) {
        $statement->add_where($column => $wheres->{$column});
    }
}


sub add_order_by {
    my ($class, %args) = @_;
    unless (defined $args{order_by}) {
        return;
    }

    my $statement = $args{statement};
    my $order_by = defined $args{order_by} ? $args{order_by} : {};
    unless (ref($order_by) eq 'ARRAY') {
        $order_by = [ $order_by ];
    }

    unless (@{ $order_by }) {
        return;
    }

    my @orders = ();
    for my $term (@{ $order_by }) {
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

sub check_table {
    my ($table) = @_;
    unless (defined $table) {
        croak "Missing 1st argument 'table'";
    }
}

1;

__END__

=head1 NAME

DBIx::Thin - A lightweight ORMapper

=cut

=head1 SYNOPSIS

 #-----------------------#
 # Your/Model.pm
 #-----------------------#
 package Your::Model;
 
 use DBIx::Thin;
 DBIx::Thin->setup(
     dsn => 'DBI:SQLite:your_project.sqlite3',
     username => '',
     password => '',
 );
 DBIx::Thin->load_defined_schemas;
 
 1;

 #-----------------------#
 # Your/Model/User.pm
 # schema class for table 'user'
 #-----------------------#
 package Your::Model::User;
 use DBIx::Thin::Schema;
 use base qw(DBIx::Thin::Row);
 
 install_table 'user' => schema {
     primary_key 'id';
     defaults string_is_utf8 => 1; # utf8 flag on
     columns 
         id    => { type => Integer },
         name  => { type => String },
         email => { type => String, utf8 => 0 }; # utf8 flag off
 };
 
 1;

 #-----------------------#
 # Your/Model/Status.pm
 # schema class for table 'status'
 #-----------------------#
 package Your::Model::Status;
 use DBIx::Thin::Schema;
 use base qw(DBIx::Thin::Row);
 
 install_table 'status' => schema {
     primary_key 'id',
     defaults string_is_utf8 => 1;
     columns 
         id    => { type => Integer },
         text  => { type => String },
         created_at => { type => Datetime },
 };
 
 1;

 #-----------------------#
 # in your script
 #-----------------------#
 use Your::Model;
 
 ### insert a record
 my $row = Your::Model->create(
     'user',
     values => {
         name => 'oinume',
         email => 'oinume_at_gmail.com',
     }
 );
 
 ### select records
 my $iterator = Your::Model->search(
     'user',
     where => { name => 'oinume' },
     limit => 20,
 );
 while (my $row = $iterator->next) {
     ...
 }
 
 ### update records
 Your::Model->update(
     'user',
     values => { name => 'new_user' },
     where => { name => 'oinume' }
 );

 ### delete records
 Your::Model->delete(
     'user',
     where => { name => 'new_user' }
 );

 ### delete a record with primary key
 Your::Model->delete_by_pk('user', 10);


=head1 CONCEPT

DBIx::Thin's conecept is very similar to L<DBIx::Skinny>'s, a simple ORMapper. You can write code other ORMappers when simple CRUD and if you execute a complex query, you can specify it directly by calling 'xxx_by_sql' method.

Although the basic idea is the same, there are some differences between DBIx::Skinny and DBIx::Thin.

=head2 Explicit interface

DBIx::Thin has more explicit interface than DBIx::Skinny's one. In Skinny, you write below to select records.

 my $itr = Your::Model->search(
     'user',
     { name => 'blur' }
 );

The 1st argument is table name and the 2nd one is 'where' conditions. In Thin, you write like this.

 my $itr = Your::Model->search(
     'user',
     where => { name => 'blur' }
 );

That is a little redundant but explicit. Arguments of Thin's methods are mostly passed by hash based style like above. It's easily understand what kind of arguments are passed.


=head2 Schema class and Row class are united

In Skinny, recommended that you define schemas like 'Your::Model::Schema' as a single file.
In Thin, schemas are defined as each class, and Row class and Schema class must be the same class for simplicity like this:

 ### Your/Model/User.pm
 package Your::Model::User;
 use DBIx::Thin::Schema;
 use base qw(DBIx::Thin::Row);
 
 install_table 'user' => schema {
     primary_key 'id';
     defaults string_is_utf8 => 1;
     columns 
         id    => { type => Integer },
         name  => { type => String },
         email => { type => String, utf8 => 0 };
 };

 ### Your/Model/Status.pm
 package Your::Model::Status;
 use DBIx::Thin::Schema;
 use base qw(DBIx::Thin::Row);
 
 install_table 'status' => schema {
     ...
 };
 
 ### code
 my $user = Your::Model->find_by_pk('user', 100);
 # $user is an instance of 'Your::Model::User'
 
 my $status = Your::Model->find_by_pk('status', 1024);
 # $status is an instance of 'Your::Model::Status'


=head2 Inflating and utf8 flag definitions are not rule based

Skinny's inflating and utf8 definitions are 'rule based', but Thin's one is not, it is basically column based like below:

 install_table 'user' => schema {
     primary_key 'id';
     columns 
         id    => { type => Integer },
         name  => { type => String, utf8 => 1 }, # utf8 flag on
         email => { type => String, utf8 => 0 }, # utf8 flag off
         created_at => {
             type => Datetime,
             inflate => sub { ... }, # specify inflate code
             deflate => sub { ... }, # specify deflate code
         },
 };

Rule based definition may have unexpected side-effects, that's why Thin avoids rule based definition. Moreover, Thin's concept is explicit interface.


=head1 SUPPORTED DATABASES

=over 4

=item * SQLite

=item * MySQL

=item * PostgreSQL

=back


=head1 METHODS

=head2 setup(%)

Set up connection info.

ARGUMENTS

  dsn: Datasource. SCALAR
  username: connect username. SCALAR
  password: connect password. SCALAR
  connect_options: connect options. HASHREF

RETURNS : nothing

EXAMPLE

  use DBIx::Thin;
  DBIx::Thin->setup(
      dsn => 'DBI:SQLite:dbname=your_project.sqlite3',
      connect_options => {
          RaiseError => 1
      }
  );
  
  OR
  
  use DBIx::Thin setup => {
      dsn => 'DBI:SQLite:dbname=your_project.sqlite3',
      connect_options => {
          RaiseError => 1
      }
  };


=head2 load_defined_schemas(%)

Loads all defined schemas automatically.
After calling load_defined_schemas,
you don't need to use your schema class like 'use Your::Model::User'.

ARGUMENTS
  
  schema_directory : directory of schema modules you created. If not given, try to find caller's package directory.

EXAMPLE

  use DBIx::Thin;
  DBIx::Thin->setup(...);
  DBIx::Thin->load_defined_schemas();
  
  OR
  
  DBIx::Thin->load_defined_schemas('another/lib/Your/Model');


=head2 new(%args)

Creates an instance of DBIx::Thin.
You shouldn't call DBIx::Thin's new method directly.
Instead, you call Your::Model's one

ARGUMENTS

  dsn: Datasource. SCALAR
  username: connect username. SCALAR
  password: connect password. SCALAR
  connect_options: connect options. HASHREF

EXAMPLE

  use Carp ();
  use Your::Model;
  
  my $model = Your::Model->new(
      dsn => 'DBI:mysql:yourdb:localhost',
      username => 'root',
      password => 'your password',
      connect_options => {
          RaiseError => 1,
          HandleError => sub { Carp::croak(shift) },
       },
  );


=head2 execute_select($sql, $bind)

Executes a query for selection. This is low level API.

ARGUMENTS

  sql : SQL
  bind : bind parameters. ARRAYREF

RETURNS : sth object


=head2 execute_update($sql, $bind)

Executes a query for updating. (INSERT, UPDATE, DELETE or others)  This is low level API.

ARGUMENTS

  sql : SQL
  bind : bind parameters. ARRAYREF

RETURNS : sth object


=head2 find_by_pk($table, $pk)

Returns a object of the table.

ARGUMENTS

  table : Table name for searching.
  pk : Primary key to find object.

RETURNS : A row object for the table. if no records, returns undef.

EXAMPLE

  my $user = Your::Model->find('user', 1);
  if ($user) {
      print 'name = ', $user->name, "\n";
  } else {
      print 'record not found.\n';
  }


=head2 find($table, %args)

Returns a object of the table.

ARGUMENTS

  table : Table name for searching
  args : HASH
    where : HASHREF
    order_by : ARRAYREF or HASHREF

RETURNS : A row object for the table. if no records, returns undef.

EXAMPLE

  my $user = Your::Model->find(
      'user',
      where => {
          name => 'hoge'
      },
      order_by => [ { name => 'ASC' }, { id => 'DESC' } ]
  );
  if ($user) {
      print "name = ", $user->name, "\n";
  } else {
      print "record not found.\n";
  }


=head2 find_by_sql(%args)

Returns a object of the table with a raw SQL.

ARGUMENTS

  args : HASH
    sql : SQL
    bind : bind parameters. ARRAYREF
    options : options. HASHREF
      utf8 : extra utf8 columns ARRAYREF
      inflate : extra inflate columns HASHREF

RETURNS : A row object for the table. if no records, returns undef.

EXAMPLE

  my $user = Your::Model->find_by_sql(
      sql => <<"EOS",
  SELECT * FROM user
  WHERE email LIKE ?
  GROUP BY name
  EOS
      bind => [ '%@gmail.com' ]
  );


=head2 search($table, %args)

Returns an iterator or an array of selected records.

ARGUMENTS

  table : Table name for searching
  args : HASH
    select : select columns. ARRAYREF
    where : HASHREF
    order_by : ARRAYREF or HASHREF
    having : HAVING
    limit  : max records number
    offset : offset

RETURNS : In scalar context, an iterator(L<DBIx::Thin::Iterator>) of row objects for the table. if no records, returns an empty iterator. (NOT undef)  In list context, an array of row objects.

EXAMPLE

  my $iterator = Your::Model->search(
      'user',
      select => [ 'id' ], # or select => [ { id => 'id_alias' } ]
      where => {
          name => { op => 'LIKE', value => 'fuga%' }
      },
      order_by => [ { name => 'ASC' }, { id => 'DESC' } ]
      limit => 20,
  );
  while (my $user = $iterator->next) {
      print "id = ", $user->id, "\n";
  }
  
  # In list context
  my @users = Your::Model->search(
      'user',
      where => {
          name => 'fuga',
      }
  );


=head2 search_by_sql($table, %args)

Returns an iterator or an array of selected records with a raw SQL.

ARGUMENTS

  args : HASH
    sql : SQL
    bind : bind parameters. ARRAYREF
    options : HASHREF
      table : Table for selection (used for determining a mapped object)
      utf8 : extra utf8 columns. ARRAYREF
      inflate : extra inflate columns. HASHREF

RETURNS : In scalar context, an iterator(L<DBIx::Thin::Iterator>) of row objects for the SQL. if no records, returns an empty iterator. (NOT undef)  In list context, an array of row objects.

EXAMPLE

  my $iterator = Your::Model->search_by_sql(
      sql => <<"EOS",
  SELECT * FROM user
  WHERE name LIKE ?
  ORDER BY id DESC
  EOS
      bind => [ '%hoge%' ]
      options => { table => 'user' },
  );
  while (my $user = $iterator->next) {
      print "id = ", $user->id, "\n";
  }
  
  # In list context
  my @users = Your::Model->search_by_sql(
      sql => <<"EOS",
  SELECT * FROM user
  WHERE name LIKE ?
  ORDER BY id DESC
  EOS
      bind => [ '%hoge%' ]
      options => {
          table => 'user',
          utf8 => [ qw(name) ],
          inflate => {
              updated_at => sub {
                  my ($column, $value) = @_;
                  # inflate to DateTime object
                  return DateTime::Format::MySQL->parse_datetime($value);
              }
          },
      },
  );


=head2 search_with_pager($table, %args)

Returns a pager and an iterator of selected records.

ARGUMENTS

  table : Table name for searching
  args : HASH
    select : select columns. ARRAYREF
    where : HASHREF
    order_by : ARRAYREF or HASHREF
    having : HAVING
    page : current page number. the default is '1'. SCALAR
    entries_per_page : entries per page. the default is '20'. SCALAR

RETURNS : a pager (L<DBIx::Thin::Pager) and an iterator(L<DBIx::Thin::Iterator>) of row objects for the table.

EXAMPLE

  my ($pager, $iterator) = Your::Model->search_with_pager(
      'user',
      select => [ 'id' ], # or select => [ { id => 'id_alias' } ]
      where => {
          name => { op => 'LIKE', value => 'fuga%' }
      },
      order_by => [ { id => 'DESC' } ],
      page => 1,
      entries_per_page => 10,
  );
  my @pages = map { $_->{page} } $pager->as_navigation;
  # --> 1 2 3 4 5 6 7 8 9 10 ...
  while (my $user = $iterator->next) {
      print "id = ", $user->id, "\n";
  }
  


=head2 search_with_pager_by_sql(%args)

Returns a pager and an iterator of selected records with a raw SQL.

ARGUMENTS

  args : HASH
    sql : SQL
    bind : bind parameters. ARRAYREF
    sql_for_count: SQL for SELECT COUNT(...).
    bind_for_ccount : bind parameters for 'sql_for_count'. ARRAYREF
    options : HASHREF
      table : Table for selection (used for determining a mapped object)
      utf8 : extra utf8 columns. ARRAYREF
      inflate : extra inflate columns. HASHREF

RETURNS : a pager (L<DBIx::Thin::Pager) and an iterator(L<DBIx::Thin::Iterator>) of row objects for the SQL.

EXAMPLE

  my ($pager, $iterator) = Your::Model->search_with_pager_by_sql(
      sql => <<"EOS",
  SELECT * FROM user
  WHERE name LIKE ?
  ORDER BY id DESC
  EOS
      bind => [ '%hoge%' ]
      options => { table => 'user' },
  );
  my @pages = map { $_->{page} } $pager->as_navigation;
  # --> 1 2 3 4 5 6 7 8 9 10 ...
  while (my $user = $iterator->next) {
      print "id = ", $user->id, "\n";
  }
  
  
  my ($pager, $iterator) = Your::Model->search_with_pager_by_sql(
      sql => <<"...",
  SELECT * FROM user
  WHERE name LIKE ?
  ORDER BY id DESC
  ...
      bind => [ '%hoge%' ],
      sql_for_count => <<"...",
  SELECT COUNT(*) FROM user
  WHERE name LIKE ?
  ORDER BY id DESC
  ..
      bind_for_count [ '%hoge%' ],
      options => { table => 'user' },
  );
  my @pages = map { $_->{page} } $pager->as_navigation;
  # --> 1 2 3 4 5 6 7 8 9 10 ...
  while (my $user = $iterator->next) {
      print "id = ", $user->id, "\n";
  }


=head2 create($table, %args)

Creates a new record.

ARGUMENTS

  table : Table name
  args : HASH
    values : Column values for a new record. HASHREF

RETURNS : A row object

EXAMPLE

  my $new_user = Your::Model->create(
      'user',
      values => {
          name => 'testname',
          email => 'testname@hoge.com',
      }
  );


=head2 create_by_sql(%args)

Executes a query for insertion. This is low level API.

ARGUMENTS

  args: HASH
    sql : SQL
    bind : bind parameters. ARRAYREF
    options : HASHREF
      fetch_created_row : Boolean. Fetch a newly created row

RETURNS : A row object


=head2 create_all($table, %args)

Creates new records.

ARGUMENTS

  table : Table name
  args : HASH
    values : Column values for a new record. HASHREF

RETURNS : Created record number.

EXAMPLE

  my $created_count = Your::Model->create_all(
      'user',
      values => [
          { name => 'test1', email => 'test1@hoge.com' },
          { name => 'test2', email => 'test2@hoge.com' },
      ],
  );


=head2 update($table, %args)

Updates records.

ARGUMENTS

  table : Table name
  args : HASH
    values : Updating values.
    where : HASHREF

RETURNS : Updated row count

EXAMPLE

  my $updated_count = Your::Mode->update(
      'user',
      values => {
          name => 'New name',
      },
      where => {
          id => 1,
      },
  );


=head2 update_by_sql(%args)

Executes a query for updating. This is low level API.

ARGUMENTS

  args: HASH
    sql : SQL
    bind : bind parameters. ARRAYREF
    options : HASHREF

RETURNS : Updated row count


=head2 delete_by_pk($table, $primary_key_value)

Delete a record with primary key value.

ARGUMENTS

  table : Table name
  primary_key_value : Primary key value for a deleted record.

RETURNS : Deleted row count

EXAMPLE

  my $deleted = Your::Model->delete_by_pk('user', 1);


=head2 delete($table, %args)

Delete records.

ARGUMENTS

  table : Table name
  args : HASH
    where : HASHREF. REQUIRED.

RETURNS : Deleted row count

EXAMPLE

  my $deleted_count = Your::Model->delete(
      'user',
      where => {
          name => 'oinume'
      }
  );


=head2 delete_by_sql(%args)

Executes a query for deleting. This is low level API.

ARGUMENTS

  args: HASH
    sql : SQL
    bind : bind parameters. ARRAYREF
    options : HASHREF

RETURNS : Deleted row count







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
