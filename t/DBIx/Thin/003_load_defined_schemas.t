#!/usr/bin/env perl

use FindBin qw/$Bin/;
use FindBin::libs;
use Test::Utils;
use Test::More tests => 2;
use Your::Model;

eval {
    Your::Model->load_defined_schemas(schema_directory => "$Bin/../../lib/Your/Model");
};
ok(!$@, 'load_defined_schemas');

eval {
    Your::Model->load_defined_schemas(schema_directory => "$Bin/../../lib/Your/Model/NotFound");
};
ok($@, 'load_defined_schemas (error)');
