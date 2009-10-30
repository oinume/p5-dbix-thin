package Your::Model::User;

use DBIx::Thin::Schema;

use base qw(DBIx::Thin::Row);

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

# getter   --> inflate
# write db --> deflate
install_table 'user' => schema {
    primary_key 'id';
    defaults
        string_is_utf8 => 1;
    
    columns(
        id => { type => Integer },
        name => { type => String },
        email => { type => String, utf8 => 0, },
        created_at => {
            type => Datetime,
            inflate => inflate_code 'dt',
            deflate => deflate_code 'dt',
        },
        updated_at => {
            type => Datetime,
            inflate => inflate_code 'dt',
            deflate => deflate_code 'dt',
        },
    );
};

1;
