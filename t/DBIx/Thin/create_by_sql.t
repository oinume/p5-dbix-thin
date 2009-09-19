#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my $name = 'create_by_sql-' . $counter++;
my $user = $model->create_by_sql(
    sql => <<"SQL",
INSERT INTO user (name, email, created_at, updated_at)
 VALUES (?, ?, ?, ?)
SQL
    bind => [ $name, $name . '@test.com', '0000-00-00 00:00:00', '0000-00-00 00:00:00' ],
    options => {
        fetch_inserted_row => 1,
    },
);
is($user->{name}, $name, 'create_by_sql');
