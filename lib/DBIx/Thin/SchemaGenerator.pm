package DBIx::Thin::SchemaGenerator;

use strict;
use warnings;
use Carp qw(croak);
use DBI;
use File::Basename qw(basename dirname);
use File::Spec::Functions qw(
    catdir catfile splitpath splitdir curdir
);
use Getopt::Long qw(GetOptionsFromArray);
use Pod::Usage;
use Term::ReadLine;

use DBIx::Thin::SchemaGenerator::DDLParser;

sub new {
    bless {}, shift;
}

sub run {
    my ($self, @args) = @_;
    # parse command line
    my ($command, @global_args, @command_args);
    for my $arg (@ARGV) {
        if ($arg =~ /^-/) {
            push @global_args, $arg;
        } else {
            push @command_args, $arg;
        }
    }

    GetOptionsFromArray(
        \@global_args,
        \my %options,
        'dsn|d=s',
        'username|u=s',
        'password|p=s',
        'primary-key|pk=s',
        'utf8|u',
        'help|h',
    ) or $self->show_usage(1, '[error]');

    if (@command_args <= 1) {
        $self->show_usage(1, qq{[error] 'TABLE_NAME' and 'MODULE_NAME' required});
    }
    
    my ($table, $module) = ($command_args[0], $command_args[1]);
#    my $primary_key = $options{primary_key};
    my $dsn = $options{dsn} || $ENV{DBIX_THIN_DSN};
    my $username = $options{username} || $ENV{DBIX_THIN_USERNAME};
    my $password = $options{password} || $ENV{DBIX_THIN_PASSWORD} || '';
    
    unless (defined $dsn) {
        $self->show_usage(1, "Must specify option 'dsn' or set env 'DBIX_THIN_DSN'");
    }
    my (undef, $driver, undef, undef, undef) =
        DBI->parse_dsn($dsn) or die "Can't parse DBI DSN '$dsn'";
    if (lc($driver) ne 'mysql') {
        print STDERR "This script now only supports 'MySQL'\n";
        exit 1;
    }

    my $parser_class = 'DBIx::Thin::SchemaGenerator::DDLParser::MySQL';
    $driver = lc $driver;
    if ($driver eq 'mysql') {
        $parser_class = 'DBIx::Thin::SchemaGenerator::DDLParser::MySQL';
#    } elsif ($driver eq 'sqlite') {
        # TODO
    } else {
        print STDERR "This script doesn't support driver '$driver'\n";
        exit 1;
    }
    my $schema_info = $parser_class
        ->new(%options)
        ->parse($table, $dsn, $username, $password);

    my %TYPES = (
        qr/^.*int.*$/ => 'Integer',
        qr/^(double|float|decimal)$/ => 'Decimal',
        qr/^(.*char.*|.*text.*|enum|set)$/ => 'String',
        qr/^(.*blob|binary)$/ => 'Binary',
        qr/^boolean$/ => 'Boolean',
        qr/^(datetime|timestamp)$/ => 'Datetime',
        qr/^(date)$/ => 'Date',
        qr/^(time)$/ => 'Time',
    );

    my $primary_key = $schema_info->{primary_key};
    my @fields = @{ $schema_info->{fields} || [] };

    my $columns = "    columns(\n";
    for my $f (@fields) {
        my $t = $f->{type};
        INNER: for my $key (keys %TYPES) {
            if ($t =~ $key) {
                $f->{normalized_type} = $TYPES{$key};
                last INNER;
            }
        }
        $columns .= "        $f->{name} => { type => $f->{normalized_type}, },\n";
    }
    $columns .= '    );';

    my $output = <<"...";
package $module;

use DBIx::Thin::Schema;
use base qw(DBIx::Thin::Row);

install_table '$table' => schema {
    primary_key '$primary_key';
$columns

1;
...

    # generate model .pm file
    my $cwd = curdir;
    my $lib_path = catdir($cwd, 'lib');
    unless (-d $lib_path) {
        print STDERR "[error] There is no `lib' directory in the current directory, this command should be called from application directory.";
        exit 4;
    }
 
    my $file = $module . '.pm';
    $file =~ s!::!/!g;
    my $dir = dirname($file);
    mkdir_p(path => catdir($lib_path, $dir));
    my $path = catfile($lib_path, $file);
    if (-e $path) {
        # Ask overwriting
        my $term = Term::ReadLine->new('DBIx::Thin::SchemaGenerator');
        my $prompt = "`$path' already exists. Overwrite? [yN] [n] ";
        my $OUT = $term->OUT || \*STDOUT;
        while (defined($_ = $term->readline($prompt))) {
            if ($_ =~ /^y$/i) {
                last;
            } else {
                exit 0;
            }
        }
    }
    
    open my $fh, '>', $path or die "$path: $!";
    print $fh $output;
    close $fh;
    
    print "`$path' created\n";
}

sub show_usage {
    my ($self, $exitval, $message) = @_;
    pod2usage({
        -exitval => $exitval,
        -message => $message
    });
}

sub mkdir_p {
    my %args = @_;
    my $path = $args{path} || croak "Must specify argument 'path'.";
    my $mask = 0777;
    if (defined $args{mask}) {
        $mask = $args{mask};
    }

    if ((splitpath($path))[0] ne '') {
        # Windows OS(full path specified)
        # TODO: implement
        # (http://www.codeproject.com/books/1578702151.asp)
        $path =~ s/\//\\/g;
        system "md $path";
    } else {
        # Create directories from top
        my @dirs = splitdir($path);
#        print "dirs: @dirs\n";
        my $base = shift @dirs;
        while (@dirs) {
            if (-d $base) {
                $base = catdir($base, shift @dirs);
                next;
            }
            mkdir $base, $mask;
            $base = catdir($base, shift @dirs);
        }
        unless (-d $base) {
            mkdir $base, $mask;
        }
    }

    croak "Can't create directory '$path'." if (! -d $path);
}

1;

__END__

=head1 NAME

 thin-generate-schema.pl - Generate model class of DBIx::Thin

=head1 SYNOPSIS

 thin-generate-schema.pl [options] TABLE_NAME MODULE_NAME

 Description:
    Generate a model class of DBIx::Thin

 Options:
    --dsn|d           Connection datasource
    --username|u      Username
    --password|p      Password
    --primary-key|pk  Primary key field
    --utf8|u          enable utf8 flag on DBIx::Thin
    --help            Print this message and exit

=cut
