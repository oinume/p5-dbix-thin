#!/usr/bin/env perl

use FindBin::libs;
use Test::Utils;
use Test::More tests => 1;

BEGIN { use_ok( 'Your::Model' ); }

my $model = Your::Model->new;
my $driver = $model->driver;
my $dbh = $driver->dbh;

my (undef, $d, undef, undef, undef) =
    DBI->parse_dsn($driver->{dsn}) or die "Can't parse DBI DSN";

if ($d =~ /sqlite/i) {
    for my $table (qw(user status)) {
        eval {
            $dbh->do("DROP TABLE $table");
        };
    }

    $dbh->do(<<"...");
CREATE TABLE user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL DEFAULT '',
    email TEXT NOT NULL DEFAULT '',
    created_at DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
    updated_at DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00'
);
...
    $dbh->do(<<"...");
CREATE TABLE status (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INT NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT '',
    created_at DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00'
);
...
    $dbh->do(<<"...");
CREATE INDEX IF NOT EXISTS user_id ON status ( user_id );
...
}

$dbh->disconnect;
