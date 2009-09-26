#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();
for my $i (0 .. 2) {
    my $name = 'find_by_sql-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}
$model->create_all('user', values => \@values);

my $user = $model->find_by_sql(
    sql => "SELECT * FROM user WHERE name LIKE ?",
    bind => [ '%find_by_sql-0%' ],
);
is($user->email, 'find_by_sql-0@test.com', 'find_by_sql');

my $user2 = $model->find_by_sql(
    sql => "SELECT * FROM user WHERE name = ?",
    bind => [ 'not_exist' ],
);
ok(!$user2, 'find_by_sql (not found)');
