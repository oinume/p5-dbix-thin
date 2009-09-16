#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;
use Your::Model::User;

my $model = Your::Model->new;

my $counter = 0;
my $name = 'update_by_sql-' . $counter++;
my $user = $model->create(
    'user',
    data => {
        name => $name,
        email => $name . '@test.com',
    },
);

$model->update_by_sql(
    sql => <<"SQL",
UPDATE user SET name = ? WHERE id = ?
SQL
    bind => [ 'updated', $user->id ],
);
my $user2 = $model->find_by_pk('user', $user->id);

is($user2->{name}, 'updated', 'update_by_sql');
