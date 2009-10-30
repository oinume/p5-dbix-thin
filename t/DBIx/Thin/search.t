#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();
for my $i (0 .. 2) {
    my $name = 'search-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}
$model->create_all('user', values => \@values);

my $iterator = $model->search(
    'user',
    where => { name => { op => 'LIKE', value => 'search%' } }
);
ok($iterator->size >= 3, 'search');

my $order_by_iterator = $model->search(
    'user',
    order_by => [
        { id => 'DESC' },
    ],
    options => { limit => 3 },
);
my @ids = ();
while (my $user = $order_by_iterator->next) {
    push @ids, $user->id;
}
# check id DESC
ok($ids[0] > $ids[1], 'search (order_by)');
ok($ids[1] > $ids[2], 'search (order_by)');

my @array = $model->search(
    'user',
    order_by => [ 'id' ],
    options => { limit => 3 },
);
# check id ASC
ok($array[0]->id < $array[1]->id, 'search (list context)');
