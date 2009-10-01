#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();
for my $i (0 .. 2) {
    my $name = 'search_by_sql-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}
$model->create_all('user', values => \@values);

my $iterator = $model->search_by_sql(
    sql => "SELECT * FROM user WHERE name LIKE ?",
    bind => [ '%search_by_sql-0%' ],
);
ok($iterator->size > 0, 'search');

my @array = $model->search_by_sql(
    sql => "SELECT * FROM user WHERE name LIKE ?",
    bind => [ '%search_by_sql-0%' ],
);
ok(@array, 'search_by_sql');

