package Your::Model::User;

use DBIx::Thin::Schema;
use base qw/DBIx::Thin::Row/;

=pod

CREATE TABLE user (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(255) NOT NULL DEFAULT '',
    email VARCHAR(255) NOT NULL DEFAULT '',
    created_at DATETIME NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

=cut
install_table 'user' => schema {
    primary_key 'id',
    columns qw/id name email created_at updated_at/,
};

1;
