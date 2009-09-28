#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();
for my $i (0 .. 2) {
    my $name = 'find_all_by_sql-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}
$model->create_all('user', values => \@values);

my $iterator = $model->find_all_by_sql(
    sql => "SELECT * FROM user WHERE name LIKE ?",
    bind => [ '%find_all_by_sql-0%' ],
);
ok($iterator->size > 0, 'find_all');

my @array = $model->find_all_by_sql(
    sql => "SELECT * FROM user WHERE name LIKE ?",
    bind => [ '%find_all_by_sql-0%' ],
);
ok(@array, 'find_all_by_sql');

