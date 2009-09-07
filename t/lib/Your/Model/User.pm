package Your::Model::User;

use DBIx::Thin::Schema;
use base qw/DBIx::Thin::Row/;

install_table 'user' => schema {
    primary_key 'id',
    columns qw/id name email created_at updated_at/,
};

1;
