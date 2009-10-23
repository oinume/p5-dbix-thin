#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();
for my $i (0 .. 2) {
    my $name = 'delete_by_sql-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}

$model->create_all('user', values => \@values);
my $deleted_count = $model->delete_by_sql(
    sql => "DELETE FROM user WHERE name LIKE ?",
    bind => [ "delete_by_sql%" ]
);
ok($deleted_count >= 3, 'delete_by_sql');

