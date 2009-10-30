#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);

{
    package Your::Model::SchemaTest;
    
    use Test::More;
    use DBIx::Thin::Schema;
    use base qw(DBIx::Thin::Row);

    install_table schema_test => schema {
        primary_key 'id';
        defaults string_is_utf8 => 1;
        columns(
            id   => { type => Integer },
            name => { type => String },
            email => { type => String, utf8 => 0 },
            icon => { type => Binary },
            created_at => { type => Datetime },
            point  => { type => Decimal },
            birthday => { type => Date },
            birth_time => { type => Time },
        );
    };
    
    my $schema_info = Your::Model::SchemaTest->schema_info;
    my @column_names = qw(id name email icon created_at point birthday birth_time);
    is_deeply($schema_info->{column_names}, \@column_names, 'columns');
    is_deeply($schema_info->{columns}->{name}, { type => 'string', utf8 => 1 }, 'columns');
    ok(Your::Model::SchemaTest->is_utf8_column('name'), 'is_utf8_column');

#    $schema_info->{
}
