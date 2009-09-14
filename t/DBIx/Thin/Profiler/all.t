#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More tests => 2;
use Your::Model;

BEGIN { use_ok('DBIx::Thin::Profiler'); }

my $model = Your::Model->new;
$model->attributes->{profile_enabled} = 1;
my $profiler = $model->profiler;

$profiler->record_query(" SELECT * FROM user WHERE email = ?", [ 'test_at_gmail.com' ]);
like($profiler->{query_logs}->[0], qr/^SELECT \* FROM user WHERE email =/, 'record_query');

