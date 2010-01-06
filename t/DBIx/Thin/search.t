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

$model->create(
    'user',
    values => {
        name => 'search-日本語',
        email => 'test@test.com',
        created_at => '2010-01-01 00:00:00',
    },
);
my @select_expected = $model->search(
    'user',
    select => [ qw(id name created_at) ],
    where => { name => { op => 'LIKE', value => 'search-日本語%' } },
    limit => 1,
);
my @select_actual = $model->search(
    'user',
    select => [
        { id => 'alias_id' },
        { name => 'alias_name' },
        { created_at => 'alias_created_at' },
    ],
    where => { name => { op => 'LIKE', value => 'search-日本語%' } },
    limit => 1,
);
is($select_actual[0]->alias_id, $select_expected[0]->id, 'search (select alias)');
is($select_actual[0]->alias_name, $select_expected[0]->name, 'search (select alias utf8)');
is(
    $select_actual[0]->alias_created_at,
    $select_expected[0]->created_at,
    'search (select alias inflate)'
);

my $order_by_iterator = $model->search(
    'user',
    order_by => [
        { id => 'DESC' },
    ],
    limit => 3,
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
    limit => 3,
);
# check id ASC
ok($array[0]->id < $array[1]->id, 'search (list context)');

