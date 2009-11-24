package Your::Model;

use strict;
use warnings;
use Carp ();
use FindBin::libs;
use DBIx::Thin;
use Your::Model::Inflate;

my $dsn = $ENV{DBIX_THIN_DSN} || 'DBI:mysql:dbix_thin_test:localhost';
my $username = $ENV{DBIX_THIN_USERNAME} || 'root';
my $password = $ENV{DBIX_THIN_PASSWORD} || '';

DBIx::Thin->setup(
    dsn => $dsn,
    username => $username,
    password => $password,
    connect_options => {
        HandleError => sub { Carp::confess(shift) },
    },
);
DBIx::Thin->load_defined_schemas;

1;
