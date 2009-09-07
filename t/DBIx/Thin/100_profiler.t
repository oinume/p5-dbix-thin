#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More tests => 1;
use Your::Model;

my $model = Your::Model->new;
$model->attributes->{profile_enabled} = 1;
my $profiler = $model->profiler("SELECT * FROM user WHERE email = ?", [ 'test_at_gmail.com' ]);
like($profiler->{query_logs}->[0], qr/^SELECT \* FROM user WHERE email =/, 'profiler');
