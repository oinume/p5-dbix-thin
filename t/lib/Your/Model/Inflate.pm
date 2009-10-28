package Your::Model::Inflate;

use strict;
use warnings;
use DBIx::Thin::Inflate;

inflate_type dt => {
    inflate => sub {
        my ($column, $value) = @_;
        $value =~ s!-!/!g; # YYYY-MM-DD hh:mm:ss -> YYYY/MM/DD hh:mm::ss
        return $value;
    },
    deflate => sub {
        my ($column, $value) = @_;
        $value =~ s!/!-!g; # YYYY/MM/DD hh:mm:ss -> YYYY-MM-DD hh:mm::ss
        return $value;
    },
};

1;
