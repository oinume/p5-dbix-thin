package Your::Model;

use strict;
use warnings;
use Carp ();
use FindBin::libs;
use DBIx::Thin;
use Your::Model::Schema::Inflate;

my $dsn = $ENV{DBIX_THIN_DSN};
unless (defined $dsn) {
    $dsn = 'DBI:SQLite:dbname=dbix_thin_test.sqlite3';

    if (system("which sqlite3 > /dev/null") == 1) {
        die 'sqlite3 must be installed';
    }
    unless (-e 'dbix_thin_test.sqlite3') {
        system "sqlite3 dbix_thin_test.sqlite3 < t/create_tables_sqlite3.sql";
    }
}

my $username = $ENV{DBIX_THIN_USERNAME} || 'root';
my $password = $ENV{DBIX_THIN_PASSWORD} || 'hoge';

DBIx::Thin->setup(
    dsn => $dsn,
    username => $username,
    password => $password,
    connect_options => {
        RaiseError => 1,
        HandleError => sub { Carp::confess(shift) },
    },
);
DBIx::Thin->load_defined_schemas;

1;
