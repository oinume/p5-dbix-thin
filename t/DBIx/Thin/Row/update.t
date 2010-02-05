#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Data::Dumper;
use Your::Model;

my $model = Your::Model->new;
my %values = (
    name => 'row-update',
    email => 'row@hoge.com',
    created_at => '2009-09-01 12:00:00',
);

Your::Model->create(
    'user',
    values => \%values,
);

# set -> update
{
    my $user = Your::Model->find(
        'user',
        where => { name => 'row-update' },
    );
    my $new_created_at = '2009-10-01 23:59:59';
    $user->set(created_at => $new_created_at);
    my $updated = $user->update;
    my $user2 = Your::Model->find_by_pk('user', $user->id);

    ok($updated, 'set -> update');
    is($user->get_raw_value('created_at'), $new_created_at, 'set -> update');
    is($user2->get_raw_value('created_at'), $new_created_at, 'set -> update');
}

# update
{
    my $user = Your::Model->find(
        'user',
        where => { name => 'row-update' },
    );
    my $new_created_at = '2010-01-01 23:59:59';
    my $new_created_at_inflated = '2010/01/01 23:59:59';
    my $updated = $user->update(created_at => $new_created_at_inflated);

    my $user2 = Your::Model->find_by_pk('user', $user->id);
    ok($updated, 'update');
    is($user->get_raw_value('created_at'), $new_created_at, 'update');
    is($user->created_at, $new_created_at_inflated, 'update (inflated)');
}

# TODO: test for dirty column
