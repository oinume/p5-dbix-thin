#!/usr/bin/env perl

use FindBin qw/$Bin/;
use FindBin::libs;
use Test::Utils;
use Test::More tests => 2;
use Your::Model;

eval {
    Your::Model->load_schema(schema_directory => "$Bin/../../lib/Your/Model");
};
ok(!$@, 'load_schema');

eval {
    Your::Model->load_schema(schema_directory => "$Bin/../../lib/Your/Model/NotFound");
};
ok($@, 'load_schema (error)');
