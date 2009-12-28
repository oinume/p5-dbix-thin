package DBIx::Thin::Driver;

=head1 NAME

DBIx::Thin::Driver - A base class for database driver

=cut

use strict;
use warnings;
use Carp qw(croak);
use DBI;
use Storable ();
use UNIVERSAL::require;
use DBIx::Thin::Utils qw(check_required_args);

my %AVAILABLE_DRIVERS = (
    mysql => 'MySQL',
    sqlite => 'SQLite',
    pg => 'PostgreSQL',
);

my @CONNECTION_INFO_KEYS = qw(dsn username password connect_options);

=head1 CLASS METHODS

=cut

=head2 new

Creates an instance.

=cut
sub new {
    my ($class, %args) = @_;
    return bless {
        dsn => $args{dsn},
        username => $args{username},
        password => $args{password},
        connect_options => $args{connect_options},
    }, shift;
}


=head2 create(%args)

Returns an instance of DBIx::Thin::Driver's sub-class.

ARGUMENTS

  dsn: Datasource
  username: username
  password: password
  connect_options: other options
  dbh: Database handle (OPTIONAL)

=cut

sub create {
    my ($class, %args) = @_;
    my $type = '';
    if (defined $args{dbh}) {
        $type = $args{dbh}->{Driver}->{Name};
    } elsif (defined $args{dsn}) {
        (undef, $type, undef) = DBI->parse_dsn($args{dsn})
            or croak "Failed to parse DSN: $args{dsn}";
    }
    $type = lc $type;
    unless ($AVAILABLE_DRIVERS{$type}) {
        # No suitable driver found.
        return __PACKAGE__->new(%args);
    }

    my $driver = 'DBIx::Thin::Driver::' . $AVAILABLE_DRIVERS{$type};
    $driver->require or croak $@;
    return $driver->new(%args);
}

sub available_drivers { return %AVAILABLE_DRIVERS }


=head1 INSTANCE METHODS

=cut

=head2 connect($args)

Connects to your database with DBI->connect.
After connect(), you can call execute_update, execute_select, etc...

Returns this driver itself.

=cut
sub connect {
    my $self = shift;
    if (@_ >= 1) {
        $self->connection_info(@_);
    }

    my $dbh = $self->{dbh};
    if ($dbh && $dbh->FETCH('Active') && $dbh->ping) {
        return $dbh;
    }

    unless (defined $self->{dsn}) {
        croak "Cannot connect because 'dsn' is not set.";
    }

    $dbh = DBI->connect(
        $self->{dsn},
        $self->{username} || '',
        $self->{password} || '',
        {
            RaiseError => 1,
            PrintError => 0,
            AutoCommit => 1,
#            HandleError => sub { Carp::confess(shift) },
            %{ $self->{connect_options} || {} }
        },
    );
    $self->{dbh} = $dbh; # cache dbh

    return $dbh;
}


sub reconnect {
    my $self = shift;
    $self->{dbh} = undef;
    return $self->connect(@_);
}

sub disconnect {
    my ($self) = @_;
    if ($self->{dbh}) {
        $self->{dbh}->disconnect();
        $self->{dbh} = undef;
    }
}

sub set_dbh {
    my ($self, $dbh) = @_;
    $self->{dbh} = $dbh;
}

sub clone {
    my ($self) = @_;

    my $dbh = delete $self->{dbh};
    my $connect_options = delete $self->{connect_options};
    my $clone = Storable::dclone($self);
    $clone->{dbh} = $dbh;
    $clone->{connect_options} = { %{ $connect_options || {} } };

    return $clone;
}

=head2 connection_info()

Get/Set DBI connection_info.

=cut
sub connection_info {
    my ($self, $connection_info) = @_;

    if (defined $connection_info) {
        for my $key (@CONNECTION_INFO_KEYS) {
            $self->{$key} = $connection_info->{$key};
        }
    }

    my %hash = ();
    for my $key (@CONNECTION_INFO_KEYS) {
        $hash{$key} = $self->{$key};
    }

    return \%hash;
}


=head2 dbh

Returns dbh. If you haven't called 'connect', this method calls 'connect' automatically.

=cut
sub dbh {
    my ($self) = @_;
    my $dbh = $self->{dbh};
    unless ($dbh && $dbh->FETCH('Active') && $dbh->ping) {
        $dbh = $self->reconnect;
    }
    return $dbh;
}

sub _dbh { return shift->{dbh} }


=head2 execute_select($sql, $bind)

Executes a query for selection.

ARGUMENTS
  sql : query to be executed
  bind : bind parameters (ARRAYREF)

=cut
sub execute_select {
    my ($self, $sql, $bind) = @_;
    my $sth;
    eval {
        $sth = $self->dbh->prepare($sql);
        $sth->execute(@{ $bind || [] });
    };
    if ($@) {
        $self->raise_error({
            sth => $sth,
            reason => "$@",
            sql => $sql,
            bind => $bind,
        });
    }

    return $sth;
}


=head2 execute_update($sql, $bind)

Executes a query for updating. (INSERT, UPDATE, DELETE)

ARGUMENTS
  sql : query to be executed
  bind : bind parameters (ARRAYREF)

=cut
sub execute_update {
    my ($self, $sql, $bind) = @_;

    my $sth;
    eval {
        $sth = $self->dbh->prepare($sql);
        $sth->execute(@{ $bind || [] });
    };
    if ($@) {
        $self->raise_error({
            sth => $sth,
            reason => "$@",
            sql => $sql,
            bind => $bind,
        });
    }

    return $sth;
}


=head2 last_insert_id

Returns id of last inserted row.

=cut
sub last_insert_id {
    warn __PACKAGE__ . ": last_insert_id returns 0";
    return 0;
}

=head2 sql_for_unixtime

Returns unixtime.
The default implementation is just calling `time()' in perl.

=cut
sub sql_for_unixtime {
    return time();
}

=head2 bulk_insert

Interface for inserting multi rows.

=cut
sub bulk_insert {
    my ($self, $model, $table, $values) = @_;
    my $dbh = $self->dbh;
    $dbh->begin_work;

    my $inserted = 0;
    for my $value ( @{$values} ) {
# TODO: adjust trigger
        $model->create($table, values => $value);
        $inserted++;
    }

    $dbh->commit;

    return $inserted;
}


sub raise_error {
    my ($class, $args) = @_;
    check_required_args([ qw(reason sql) ], $args);

    Data::Dumper->require or croak $@;
    $args->{sth} && $class->close_sth($args->{sth});
    my $sql = $args->{sql};
    $sql =~ s/\n/\n          /gm;
    croak(<<"EOS");
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
@@@@@   DBIx::Thin's Error   @@@@
Reason: $args->{reason}
SQL   : $args->{sql}
Bind  : @{[ Data::Dumper::Dumper($args->{bind} || []) ]}
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
EOS
}

sub close_sth {
    my ($class, $sth) = @_;
    $sth->finish;
    undef $sth;
}

sub DESTORY {
    my $self = shift;
    $self->disconnect();
}

1;
