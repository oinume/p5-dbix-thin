#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Data::Dumper;
use Your::Model;

my $model = Your::Model->new;
my $name = 'row-delete-' . $$;
my %values = (
    name => $name,
    email => 'row@hoge.com',
    created_at => '2009-09-01 12:00:00',
);

Your::Model->create(
    'user',
    values => \%values,
);

my $user = Your::Model->find(
    'user',
    where => { name => $name },
);
$user->delete;

my $user2 = Your::Model->find(
    'user',
    where => { name => $name },
);

ok(!$user2, 'delete');
