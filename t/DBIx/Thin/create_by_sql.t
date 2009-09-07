#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;
use Your::Model::User;

my $model = Your::Model->new;

my $counter = 0;
my $name = 'create_by_sql-' . $counter++;
my $user = $model->create_by_sql(
    'user',
    {
        sql => <<"SQL",
INSERT INTO user (name, email, created_at)
 VALUES (?, ?, NOW())
SQL
        bind => [ $name, $name . '@test.com' ],
    },
);
is($user->{name}, $name, 'create_by_sql');
