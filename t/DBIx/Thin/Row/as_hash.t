#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Data::Dumper;
use Your::Model;

my $model = Your::Model->new;
my %values = (
    name => 'row-as_hash',
    email => 'oinume@hoge.com',
    created_at => '2009-09-01 12:00:00',
);

Your::Model->create(
    'user',
    values => \%values,
);

my $user = Your::Model->find(
    'user',
    where => { name => 'row-as_hash' },
);
my %hash = $user->as_hash;

is($hash{created_at}, $user->created_at, 'as_hash');


