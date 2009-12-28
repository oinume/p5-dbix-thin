#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More 'no_plan';
use Your::Model;

my $schema_class = Your::Model->schema_class('user');
is($schema_class, 'Your::Model::User', 'schema_class');

my $schema_class2 = Your::Model->schema_class('__notfound');
is($schema_class2, 'DBIx::Thin::Row', 'schema_class (DBIx::Thin::Row)');

eval {
    Your::Model->schema_class('__notfound', 1);
};
ok($@, 'schema_class (not found error)');

