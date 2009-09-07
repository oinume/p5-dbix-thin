#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More tests => 1;
use Your::Model;

my $model = Your::Model->new;
is($model->{klass}, 'Your::Model', 'new');

use Data::Dumper;

print Dumper $model;
