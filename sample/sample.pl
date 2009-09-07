package Your::Model;

=pod

CREATE TABLE user (
    id INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL DEFAULT '',
    email VARCHAR(50) NOT NULL DEFAULT '',
    created_at DATETIME NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    PRIMARY KEY (id)
) ENGINE=InnoDB;

=cut

use strict;
use warnings;
use Carp ();
use Data::Dumper;
use FindBin::libs;
use DBIx::Thin;
use base qw/DBIx::Thin/;

DBIx::Thin->setup(
    dsn => 'DBI:mysql:dbix_thin:localhost',
    username => 'root',
    password => '',
    connect_info => {
        RaiseError => 1,
        HandleError => sub { Carp::confess(shift) },
    },
);

package Your::Model::User;
use DBIx::Thin::Schema;
use base qw/DBIx::Thin::Row/;

install_table 'user' => schema {
    primary_key 'id',
    columns qw/id name email created_at updated_at/,
};

use Data::Dumper;
print Dumper __PACKAGE__->schema_info;

package main;

use strict;
use warnings;
use Data::Dumper;

my $model = Your::Model->new;
my $value = Your::Model->create(
    'user',
    {
        name => 'oinume',
        email => 'oinume_at_gmail.com',
    }
);
# or
# $model->create(...);
print Dumper $value;

#Your::Model
