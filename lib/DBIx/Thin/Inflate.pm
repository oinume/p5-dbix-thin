package DBIx::Thin::Inflate;

use strict;
use warnings;
use Carp qw/croak/;
#$Carp::Internal{(__PACKAGE__)}++;

our %INFLATE = (
    inflate => {
        Hex  => sub { unpack("H*", $_[0]) },
    },
    deflate => {
        Hex  => sub { pack("H*", $_[0]) },
    },
);

sub import {
    my $class  = shift;
    my $caller = caller;

    no strict 'refs';
    *{"$caller\::inflate_code"} = \&inflate_code;
    *{"$caller\::deflate_code"} = \&deflate_code;
    *{"$caller\::inflate_type"} = \&inflate_type;
}

sub inflate_code($) {
    my ($name) = @_;
    my $code = $INFLATE{inflate}->{$name};
    unless (defined $code) {
        croak "No inflate code for '$name'.";
    }
    return $code;
}

sub deflate_code($) {
    my ($name) = @_;
    my $code = $INFLATE{deflate}->{$name};
    unless (defined $code) {
        croak "No deflate code for '$name'.";
    }
    return $code;
}

sub inflate_type($$) {
    my ($name, $hashref) = @_;
    for my $type (qw/inflate deflate/) {
        if (ref($hashref->{$type}) eq 'CODE') {
            if ($INFLATE{$type}->{$name}) {
                my $caller = caller;
                croak "The inflate_type '$name' has already been created, cannot be created again in $caller"
            }
            $INFLATE{$type}->{$name} = $hashref->{$type};
        }
    }
}

1;
