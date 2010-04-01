#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Your::Model;

my $model = Your::Model->new;

my $iterator = $model->search_by_sql(
    sql => <<"...",
SELECT * FROM user
LIMIT 5
...
);
ok($iterator, 'get_table');

$iterator = $model->search_by_sql(
    sql => <<"...",
SELECT *
FROM user AS u
LIMIT 5
...
);
ok($iterator, 'get_table');

my $row = $model->find_by_sql(
    sql => <<"...",
SELECT *
FROM user AS u
INNER JOIN status AS s ON u.id = s.user_id
LIMIT 1
...
);
ok($row, 'get_table');
