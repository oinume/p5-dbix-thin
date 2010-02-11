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
    my $name = 'count-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}
$model->create_all('user', values => \@values);

# count
{
    my $count = $model->count(
        'user',
        where => { name => { op => 'LIKE', value => 'count-%' } },
        order_by => [ 'created_at' ],
    );
    ok($count > 0, 'count');
}
