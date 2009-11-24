package DBIx::Thin::Inflate;

use strict;
use warnings;
use Carp qw(croak);
#$Carp::Internal{(__PACKAGE__)}++;

use base qw(Exporter);

our @EXPORT_OK = qw(
    inflate_definitions get_inflate_code get_deflate_code
);
our @EXPORT = qw(register_inflate);

my %Definitions = (
    inflate => {
        Hex  => sub { unpack("H*", $_[0]) },
    },
    deflate => {
        Hex  => sub { pack("H*", $_[0]) },
    },
);

# TODO: delete
#sub import {
#    my $class  = shift;
#    my $caller = caller;
#
#    {
#        no strict 'refs';
#        for my $f (qw(inflate_definitions
#                      get_inflate_code
#                      get_deflate_code
#                      register_inflate)) {
#
#            *{"$caller\::$f"} = \&$f;
#        }
#    }
#}

sub inflate_definitions() {
    return %Definitions;
}

sub get_inflate_code($) {
    my ($name) = @_;
    return $Definitions{inflate}->{$name};
}

sub get_deflate_code($) {
    my ($name) = @_;
    return $Definitions{deflate}->{$name};
}

sub register_inflate($$) {
    my ($name, $hashref) = @_;
    for my $type (qw(inflate deflate)) {
        if (ref($hashref->{$type}) eq 'CODE') {
            if ($Definitions{$type}->{$name}) {
                my $caller = caller;
                croak "The inflate_type '$name' has already been created, cannot be created again in $caller"
            }
            $Definitions{$type}->{$name} = $hashref->{$type};
        }
    }
}

1;
