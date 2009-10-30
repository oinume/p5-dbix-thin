package DBIx::Thin::Accessor;

use strict;
use warnings;
use Class::Accessor::Fast;

use base qw(Class::Accessor::Fast);

sub new {
    my ($proto, @fields) = @_;
    my $class = ref $proto || $proto;
    my $fields_ref = {};
    if (@fields >= 2) {
        $fields_ref = { @fields };
    } elsif (@fields == 1) {
        $fields_ref = $fields[0];
    }

    return bless $fields_ref, $class;
}

1;
