#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More qw(no_plan);
use Your::Model;

my $model = Your::Model->new;

my $counter = 0;
my @values = ();
for my $i (0 .. 2) {
    my $name = 'search_by_sql-' . $counter++;
    push @values, {
        name => $name,
        email => $name . '@test.com',
    };
}
$model->create_all('user', values => \@values);

my $iterator = $model->search_by_sql(
    sql => "SELECT * FROM user WHERE name LIKE ?",
    bind => [ '%search_by_sql-0%' ],
);
ok($iterator->size > 0, 'scalar context (iterator)');

my @array = $model->search_by_sql(
    sql => "SELECT * FROM user WHERE name LIKE ?",
    bind => [ '%search_by_sql-0%' ],
);
ok(@array, 'list context (array)');

my $user = $model->create(
    'user',
    values => {
        name => 'search_by_sqlの名前-' . $counter++,
        email => 'search_by_sql' . $counter++ . '@test.com',
    },
);

my @statuses = ();
$counter = 0;
for my $i (0 .. 5) {
    my $status = '新しいstatus:' . $counter++;
    push @statuses, {
        user_id => $user->id,
        status => $status,
    };
}
$model->create_all(
    'status',
    values => \@statuses
);

my @array2 = $model->search_by_sql(
    sql => <<"EOS",
SELECT s.*, u.name, u.email, u.updated_at FROM status AS s
LEFT JOIN user AS u ON s.user_id = u.id
WHERE u.id = ?
EOS
    bind => [ $user->id ],
    options => {
        utf8 => [ qw(name email) ],
        inflate => {
        updated_at => DBIx::Thin::Schema::inflate_code 'dt',
# TODO: implement
#            updated_at => sub { print "inflate updated_at!!\n" },
        }
    },
);
unlike($array2[0]->updated_at, qr/-/, 'inflate');
