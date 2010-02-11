#!/usr/bin/env perl

use utf8;
use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();
for my $i (0 .. 2) {
    my $name = 'count_by_sql-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}
$model->create_all('user', values => \@values);

# count_by_sql
{
    my $count = $model->count_by_sql(
        sql => "SELECT COUNT(*) FROM user WHERE name LIKE ?",
        bind => [ 'count_by_sql-%' ],
    );
    ok($count > 0, 'count_by_sql');
}
