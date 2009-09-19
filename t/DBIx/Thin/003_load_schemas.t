#!/usr/bin/env perl

use FindBin qw/$Bin/;
use FindBin::libs;
use Test::Utils;
use Test::More tests => 2;
use Your::Model;
use DBIx::Thin;

eval {
    DBIx::Thin->load_schemas(schema_directory => "$Bin/../../lib/Your/Model");
};
ok(!$@, 'load_schema');

eval {
    DBIx::Thin->load_schemas(schema_directory => "$Bin/../../lib/Your/Model/NotFound");
};
ok($@, 'load_schema (error)');
