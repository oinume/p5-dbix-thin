package Your::Model;

use strict;
use warnings;
use Carp ();
use FindBin::libs;
use DBIx::Thin;

# TODO: MySQL or SQLite or PostgreSQL setup
DBIx::Thin->setup({
    dsn => 'DBI:mysql:dbix_thin:localhost',
    username => 'root',
    password => '',
    connect_options => {
        HandleError => sub { Carp::confess(shift) },
    },
});

1;
