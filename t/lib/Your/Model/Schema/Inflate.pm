package Your::Model::Schema::Inflate;

use strict;
use warnings;
use DBIx::Thin::Schema::Inflate;

register_inflate dt => {
    inflate => sub {
        my ($column, $value) = @_;
        $value =~ s!-!/!g; # YYYY-MM-DD hh:mm:ss -> YYYY/MM/DD hh:mm:ss
        return $value;
    },
    deflate => sub {
        my ($column, $value) = @_;
        $value =~ s!/!-!g; # YYYY/MM/DD hh:mm:ss -> YYYY-MM-DD hh:mm:ss
        return $value;
    },
};

1;
