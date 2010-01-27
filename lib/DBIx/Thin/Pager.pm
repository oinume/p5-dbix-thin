package DBIx::Thin::Pager;

use strict;
use warnings;
use Carp qw(croak);
use Data::Page;

=head1 NAME

 DBIx::Thin::Pager - A pagenation module for DBIx::Thin

=cut

=head1 CLASS METHODS

=head2 new(%)

Creates an instance of DBIx::Thin::Pager.

ARGUMENTS

  total_entries : Total entry count with all pages. SCALAR
  entries_per_page: Entry count per page. SCALAR
  current_page    : Current page number. SCALAR

=cut

sub new {
    my ($class, %args) = @_;
    my ($total_entries, $entries_per_page, $current_page, $max_page) = $class->validate_pager_data(
        total_entries    => $args{total_entries},
        entries_per_page => $args{entries_per_page},
        current_page     => $args{current_page},
    );

    my $self = bless {
        _page => Data::Page->new(
            $total_entries,
            $entries_per_page,
            $current_page,
        ),
        max_page => $max_page
    };

    # max pages for navigation
    $self->page_limit_in_navigation(10);

    return $self;
}

sub validate_pager_data {
    my ($class, %args) = @_;

    my $total_entries = (defined $args{total_entries}
                         && $args{total_entries} =~ /^\d+$/
                         && int($args{total_entries}) > 0) ? int($args{total_entries}) : 0;
    my $entries_per_page = (defined $args{entries_per_page}
                            && $args{entries_per_page} =~ /^\d+$/
                            && int($args{entries_per_page}) > 0) ?
                                int($args{entries_per_page}) : 20;
    my $current_page = (defined $args{current_page}
                        && $args{current_page} =~ /^\d+$/
                        && $args{current_page} > 0) ? int($args{current_page}) : 1;

    # If the current page number exceeds max page number,
    # the page number is set to the last page number.
    my $max_page = ceil($total_entries / $entries_per_page);
    if ($max_page != 0 && $max_page < $current_page) {
        $current_page = $max_page;
    }

    return ($total_entries, $entries_per_page, $current_page, $max_page);
}

sub valid_current_page {
    my ($class, %args) = @_;
    my @data = $class->validate_pager_data(%args);
    return $data[2];
}

=head1 INSTANCE METHODS

=head2 entries_per_page()

Returns entry count per page.

=cut
sub entries_per_page { shift->page->entries_per_page }


=head2 first_page()

Returns the first page number which starts from 1.

=cut
sub first_page { shift->page->first_page }


=head2 last_page()

Returns the last page number.

=cut
sub last_page { shift->page->last_page }


=head2 current_page()

Returns the current page number.

=cut
sub current_page { shift->page->current_page }


=head2 first()

Returns the first entry number of current page.

=cut
sub first { shift->page->first }


=head2 last()

Returns the last entry number of current page.

=cut
sub last { shift->page->last }


=head2 total_entries()

Returns total entry count with all pages.

=cut
sub total_entries { shift->page->total_entries }


=head2 previous_page()

Returns a previous page number of the current page.

=cut
sub previous_page { shift->page->previous_page }


=head2 next_page()

Returns a next page number of the current page.

=cut
sub next_page { shift->page->next_page }


=head2 previous_entries()

Returns entry count of a previous page.

=cut
sub previous_entries {
    my ($self) = @_;

    my $prev = $self->previous_page;
    return 0 if (!$prev);

    my $current_page_save = $self->current_page;
    # Set the current page number to a previous page temporarily
    $self->page->current_page($prev);
    # Get entry count of a previous page
    my $prev_entries = $self->page->entries_on_this_page;
    # Set the current page back
    $self->page->current_page($current_page_save);

    return $prev_entries;
}


=head2 next_entries()

Returns entry count of a next page.

=cut
sub next_entries {
    my ($self) = @_;

    my $next = $self->next_page;
    unless ($next) {
        return 0;
    }

    my $current_page_save = $self->current_page;
    $self->page->current_page($next);
    my $next_entries = $self->page->entries_on_this_page;
    $self->page->current_page($current_page_save);

    return $next_entries;
}


=head2 page_limit_in_navigation($limit)

Page limit for a navigation. The default is 10.

=cut
sub page_limit_in_navigation {
    my ($self, @args) = @_;

    if (@args) {
        # set
        my $limit = $args[0];
        if ($limit % 2 != 0) {
            # TODO: no error
            croak "Argument can't be odd number.";
        }
        $self->{page_limit_in_navigation} = $limit;
    } else {
        # get
        return $self->{page_limit_in_navigation};
    }
}

=head2 is_previous_first_page()

Returns true if a previous page is the first page.

=cut
sub is_previous_first_page {
    return shift->previous_page == 1 ? 1 : 0;
}

=head2 is_single_page()

Returns true if page count is one.

=cut
sub is_single_page {
    my ($self) = @_;
    return ($self->previous_page == 0 && $self->next_page == 0)? 1 : 0;
}

=head2 as_navigation()

Returns an array of page numbers for navigation.
The data structure is below.

 (
     {
         is_current_page => True if the page number is the current page
         page            => Page number
         is_first_page_in_navigation => True if this page is the first page in navigation
         is_last_page_in_navigation  => True if this page is the last page in navigation
     },
     ...
 )

If specify arguments 'additional_navigation_params', specified parameters are set to each HASHREF data of above array.
For example:

 $pager->as_navigation(
     additional_navigation_params => { aaa => 'bbb' }
 )

becomes

 (
     {
         is_current_page => 1,
         page            => 2,
         is_first_page_in_navigation => 0,
         is_last_page_in_navigation  => 0,
         aaa => 'bbb', # * this
     },
     ...
 )

=cut
sub as_navigation {
    my ($self, %args) = @_;
    if (defined $args{additional_navigation_params}
        && ref $args{additional_navigation_params} ne 'HASH'
    ) {
        croak "Argument additional_navigation_params must be HASHREF";
    }

    my $limit = $self->page_limit_in_navigation;

    my $first_page = $self->first_page;
    if ($self->last_page > $limit && $self->previous_page) {
        my $first = $self->current_page - (int($limit / 2) - 1);
        $first_page =  $first if ($first > 0);
    }

    my $last_page = $self->last_page;
    if ($self->last_page > $limit && $self->next_page) {
        my $last = $self->current_page + (int($limit / 2));
        $last_page = $last if ($last <= $self->page->last_page);
    }

    my ($page, @array);
    my $entries_per_page = $self->entries_per_page;
    for my $i ($first_page .. $last_page) {
        push @array, {
            is_current_page => ($self->current_page == $i) ? 1 : 0,
            page => $i,
            entries_per_page => $entries_per_page,
            is_first_page => $i == 1 ? 1 : 0,
            %{ $args{additional_navigation_params} || {} },
        };
        $page = $i;
    }

    if ($self->last_page <= $limit) {
        $array[0]->{is_first_page_in_navigation} = 1;
        $array[$#array]->{is_last_page_in_navigation} = 1;
        return @array;
    }

    if ($self->last_page == $page) {
        # fill backward data of the current page
        $page = $first_page;
        while (scalar @array < $limit && $page > 1) {
            $page--;
            unshift @array, {
                is_current_page => 0,
                is_first_page => $page == 1 ? 1 : 0,
                page => $page,
                entries_per_page => $entries_per_page,
                %{ $args{additional_navigation_params} || {} },
            };
        }
    } else {
        # fill forward data of the current page
        while (scalar @array < $limit) {
            $page++;
            push @array, {
                is_current_page => 0,
                is_first_page => $page == 1 ? 1 : 0,
                page => $page,
                entries_per_page => $entries_per_page,
                %{ $args{additional_navigation_params} || {} },
            };
        }
    }

    $array[0]->{is_first_page_in_navigation} = 1;
    $array[$#array]->{is_last_page_in_navigation} = 1;
    return @array;
}


sub page { shift->{_page} }

sub ceil {
    my ($num) = @_;
    my $value = ($num > 0 && $num != int($num)) ? 1 : 0;
    return int($num + $value);
}

1;
