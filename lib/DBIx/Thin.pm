package DBIx::Thin;

use strict;
use warnings;
use Carp qw/croak/;

our $VERSION = '0.01';

use DBI;
use Storable ();
use UNIVERSAL::require;
use DBIx::Thin::Statement;
use DBIx::Thin::Utils qw/check_required_args/;

sub import {
    strict->import;
}

sub setup {
    my ($class, $args) = @_;
    my %args = %{ $args || {} };

    my $caller = caller;
    my $driver = $class->create_driver(\%args);
    my $attributes = +{
        dsn             => $args{dsn},
        username        => $args{username},
        password        => $args{password},
        connect_options => $args{connect_options},
        dbh             => $args{dbh} || undef,
        driver          => $driver,
        schemas         => {},
        profiler        => undef,
        profile_enabled => $ENV{DBIX_THIN_PROFILE} || 0,
        klass           => $caller,
# TODO: deleted
#        row_class_map   => +{},
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
    my $dbh      = delete $attr->{dbh};
    my $connect_options = delete $attr->{connect_options};

    my $self = bless Storable::dclone($attr), $class;
    if ($connection_info) {
        $self->connection_info($connection_info);
        $self->reconnect;
    } else {
        $self->attributes->{driver} = $driver;
        $self->attributes->{dbh} = $dbh;
        $self->attributes->{connect_options} = $connect_options;
    }
    $self->attributes->{profiler} = $profiler;

    return $self;
}

sub schema_class {
    my ($class, $table) = @_;
    my $schema = $class->attributes->{schemas}->{$table};
    unless ($schema) {
        DBIx::Thin::Schema->require or croak $@;
        $schema = DBIx::Thin::Schema::table2schema_class($table);
        $class->attributes->{schemas}->{$table} = $schema;
        $schema->require or croak $@;
    }

    return $schema;
}

sub profiler {
    # TODO: profilerの出力確認
    my ($class, $sql, $bind) = @_;
    my $attr = $class->attributes;

    unless ($attr->{profiler}) {
        DBIx::Thin::Profiler->require or croak $@;
        $attr->{profiler} = DBIx::Thin::Profiler->new;
    }
    if ($attr->{profile_enabled} && $sql) {
        $attr->{profiler}->record_query($sql, $bind);
    }

    return $attr->{profiler};
}

sub connection_info {
    my ($class, $connection_info) = @_;

    my $attr = $class->attributes;
    if (defined $connection_info) {
        for my $key (qw/dsn username password connect_options/) {
            $attr->{$key} = $connection_info->{$key};
        }
        $attr->{driver} = $class->create_driver($connection_info);
    }

    return Storable::dclone $attr;
}

sub create_driver {
    my ($class, $args) = @_;
    my $type = '';
    if ($args->{dbh}) {
        $type = $args->{dbh}->{Driver}->{Name};
    } elsif ($args->{dsn}) {
        (undef, $type, undef) = DBI->parse_dsn($args->{dsn})
            or croak "Failed to parse DSN: $args->{dsn}";
    }

    my %DRIVERS = (
        mysql => 'MySQL',
        sqlite => 'SQLite',
        # TODO: PostgreSQL
    );
    unless ($DRIVERS{$type}) {
        # suitable driver not found
        DBIx::Thin::Driver->require or croak $@;
        return DBIx::Thin::Driver->new;
    }

    my $driver = 'DBIx::Thin::Driver::' . $DRIVERS{$type};
    $driver->require or croak $@;
    return $driver->new;
}

sub connect {
    my $class = shift;

    if (@_ >= 1) {
        $class->connection_info(@_);
    }

    my $attr = $class->attributes;
    if ($attr->{dbh}) {
        return $attr->{dbh};
    }

    $attr->{dbh} = DBI->connect(
        $attr->{dsn},
        $attr->{username},
        $attr->{password},
        {
            RaiseError => 1,
            PrintError => 0,
            AutoCommit => 1,
#            HandleError => sub { Carp::confess(shift) },
            %{ $attr->{connect_options} || {} }
        },
    );

    return $attr->{dbh};
}

sub reconnect {
    my $class = shift;
    $class->attributes->{dbh} = undef;
    $class->connect(@_);
}

sub set_dbh {
    my ($class, $dbh) = @_;
    $class->attributes->{dbh} = $dbh;
}

sub driver { shift->attributes->{driver} }

sub dbh {
    my $class = shift;
    my $dbh = $class->connect;
    unless ($dbh && $dbh->FETCH('Active') && $dbh->ping) {
        $dbh = $class->reconnect;
    }
    return $dbh;
}

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
    $class->profiler($sql, \@bind);

    my $sth = $class->execute_update($sql, \@bind);
    my $last_insert_id = $class->driver->last_insert_id(
        dbh => $class->dbh,
        sth => $sth,
    );
    $class->close_sth($sth);

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
    $class->profiler($sql, \@bind);

    my $sth = $class->execute_update($sql, \@bind);
    my $last_insert_id = $class->driver->last_insert_id(
        dbh => $class->dbh,
        sth => $sth,
    );
    $class->close_sth($sth);

    my $object = $schema->new;
    if ($args->{reselect_inserted_row}) {
        $object = $class->find_by_pk($last_insert_id);
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
    my $bulk_insert = $class->driver->can('bulk_insert')
        or croak "driver doesn't provide bulk_insert method.";
    my $inserted = $bulk_insert->($class, $table, $values);
    return $inserted;
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
    $class->profiler($sql, \@bind);

    my $sth = $class->execute_update($sql, \@bind);
    my $rows = $sth->rows;
# TODO:
#    $class->call_schema_trigger('post_update', $schema, $table, $rows);

    return $rows;
}

sub update_by_sql {
    my ($class, $sql, $bind, $opts) = @_;
    $class->profiler($sql, $bind);

# TODO: schema使う？
#    my $table = $opts->{table};
#    unless (defined $table) {
#        if ($sql =~ /^update\s+([\w]+)\s/i) {
#            $table = $1;
#        }
#    }
#    my $schema = $class->schema_class($table);

    my $sth = $class->execute_update($sql, $bind);
    my $updated = $sth->rows;
    $class->close_sth($sth);

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
    $class->profiler($sql, $bind);
    my $sth = $class->execute_update($sql, $bind);

#    $class->call_schema_trigger('post_delete', $schema, $table);

    my $deleted = $sth->rows;
    $class->close_sth($sth);
    
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
    $class->profiler($sql, $statement->bind);
    my $sth = $class->execute_update($sql, $statement->bind);

#    $class->call_schema_trigger('post_delete_all', $schema, $table);

    my $deleted = $sth->rows;
    $class->close_sth($sth);

    return $deleted;
}


sub delete_by_sql {
    my ($class, $sql, $bind) = @_;

    $class->profiler($sql, $bind);
    my $sth = $class->execute_update($sql, $bind);
#    $class->call_schema_trigger('post_delete_by_sql', $schema, $table);
    my $deleted = $sth->rows;
    $class->close_sth($sth);
    
    return $deleted;
}

sub execute_update {
    my ($class, $sql, $bind) = @_;

    # TODO: doとどっちが速いかベンチを取る
    my $sth;
    eval {
        $sth = $class->dbh->prepare($sql);
        $sth->execute(@{ $bind || [] });
    };
    if ($@) {
        $class->raise_error({
            sth => $sth,
            reason => "$@",
            sql => $sql,
            bind => $bind,
        });
    }

    return $sth;
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

    $class->profiler($sql, $bind);
    my $sth = $class->execute_select($sql, $bind);
    my $row = $sth->fetchrow_hashref;
    unless ($row) {
        $class->close_sth($sth);
        return undef;
    }
    $class->close_sth($sth);

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

    $class->profiler($sql, $bind);
    my $sth = $class->execute_select($sql, $bind);

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

# TODO: delete
#sub row_class {
#    my ($class, $table) = @_;
#
#    my $attr = $class->attribute;
#
#    if ( $base_row_class eq 'DBIx::Skinny::Row' ) {
#        return $class->_mk_anon_row_class($key, $base_row_class);
#    } elsif ($base_row_class) {
#        return $base_row_class;
#    } elsif ($table) {
#        my $tmp_base_row_class = join '::', $attr->{klass}, 'Row', _camelize($table);
#        eval "use $tmp_base_row_class"; ## no critic
#        if ($@) {
#            $attr->{row_class_map}->{$table} = 'DBIx::Skinny::Row';
#            return $class->_mk_anon_row_class($key, $attr->{row_class_map}->{$table});
#        } else {
#            $attr->{row_class_map}->{$table} = $tmp_base_row_class;
#            return $tmp_base_row_class;
#        }
#    } else {
#        return $class->_mk_anon_row_class($key, 'DBIx::Skinny::Row');
#    }
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

sub execute_select {
    my ($class, $sql, $bind) = @_;
    my $sth;
    eval {
        $sth = $class->dbh->prepare($sql);
        $sth->execute(@{ $bind || [] });
    };
    if ($@) {
        $class->raise_error({
            sth => $sth,
            reason => "$@",
            sql => $sql,
            bind => $bind,
        });
    }

    return $sth;
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


sub raise_error {
    my ($class, $args) = @_;
    check_required_args([ qw/sth reason sql bind/ ], $args);

    Data::Dumper->require or croak $@;
    $args->{sth} && $class->close_sth($args->{sth});
    my $sql = $args->{sql};
    $sql =~ s/\n/\n          /gm;
    croak(<<"EOS");
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@   DBIx::Thin's Error   @@@@@@@@
Reason: $args->{reason}
SQL   : $args->{sql}
Bind  : @{[ Data::Dumper::Dumper($args->{bind}) ]}
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
EOS
}

sub close_sth {
    my ($class, $sth) = @_;
    $sth->finish;
    undef $sth;
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
