#!/usr/bin/env perl

use utf8;
use FindBin::libs;
use Test::Utils;
use Test::More qw/no_plan/;
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();
for my $i (0 .. 2) {
    my $name = 'update-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}

my $name2 = 'アップデート済み';
$model->create_all('user', values => \@values);
my $updated_count = $model->update(
    'user',
    values => {
        name => $name2,
        email => 'updated@test.com',
        created_at => '2009-09-30 18:01:01',
    },
    where => {
        name => 'update-0',
    },
);
is($updated_count, 1, 'update');

# check utf8
my $user2 = $model->find('user', where => { email => 'updated@test.com' });
is($user2->name, $name2, 'update (utf8_off)');
ok(utf8::is_utf8($user2->name), 'update (utf8_on)');

# check deflate
is($user2->get_raw_value('created_at'), '2009-09-30 18:01:01', 'update (deflate)');
