package Your::Model::Status;

use DBIx::Thin::Schema;

use base qw(DBIx::Thin::Row);

=pod

CREATE TABLE status (
    id INT NOT NULL AUTO_INCREMENT,
    user_id INT NOT NULL DEFAULT 0,
    status TEXT NOT NULL DEFAULT '',
    created_at DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
    PRIMARY KEY (id),
    KEY user_id (user_id)
);

=cut

install_table 'status' => schema {
    primary_key 'id';
    defaults
        string_is_utf8 => 1;
    
    columns(
        id => { type => Integer },
        user_id => { type => Integer },
        status => { type => String },
        created_at => {
            type => Datetime,
            inflate => inflate_code 'dt',
            deflate => deflate_code 'dt',
        },
    );
};

1;
