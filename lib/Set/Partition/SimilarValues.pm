package Set::Partition::SimilarValues;
use strict;
use Carp;

use constant DEF_MIN_SET_SIZE => 3;
use constant DEF_GRP_SEP_FACTOR => 1.0;

use vars qw($VERSION);

$VERSION = sprintf"%d.%03d", q$Revision: 1.3 $ =~ /: (\d+)\.(\d+)/;

sub new {
	my ($class, %opts) = @_;

	my %self = (
		MinSetSize => DEF_MIN_SET_SIZE,
		GroupSeparationFactor => DEF_GRP_SEP_FACTOR,
	);

	if (exists $opts{'MinSetSize'}) {
		my $sz = $opts{'MinSetSize'};
		croak("The MinSetSize value must be positive") unless $sz > 0;
		croak("The MinSetSize value must be an integer") unless $sz == int($sz);
		$self{'MinSetSize'} = $sz;
	}
	if (exists $opts{'GroupSeparationFactor'}) {
		my $factor = $opts{'GroupSeparationFactor'};
		croak("The GroupSeparationFactor value must be greater than 0") unless ($factor > 0);
		$self{'GroupSeparationFactor'} = $factor;
	}
	if ($opts{'ItemDataKey'}) {
		$self{'ItemDataKey'} = $opts{'ItemDataKey'};
	}
	if ($opts{'MaxGroups'}) {
		my $mg = $opts{'MaxGroups'};
		croak("The MaxGroups value must be greater than or equal to 2") unless ($mg >= 2);
		croak("The MaxGroups value must be an integer") unless $mg == int($mg);
		$self{'MaxGroups'} = int($mg);
	}

	return bless \%self, $class;
}

sub merge_small_sets {
	my $self = shift;
	my $sz = $self->{'MinSetSize'};
	my @groups = @_;
	
	# input checks
	foreach (@groups) {
		croak("You must supply a list solely of array references") unless (ref($_) eq 'ARRAY');
	}

	my $flag = 1;	# indicate whether we've modified any groups
	while ((@groups > 1) &&	($flag)) {	# no work to do if there are 0 or 1 groups!
		TRACE(__PACKAGE__." merge: scanning ".@groups." groups");
		$flag = 0;
		my $i = 0;
		while ($i <= $#groups) {
			TRACE(__PACKAGE__." merge: examining group $i");
			my @tmp = @{ $groups[$i] };
			if (@tmp < $sz) {
				TRACE(__PACKAGE__." merge: ...undersized");
				# if the small group is the last, merge it with the previous one...
				if ($i == $#groups) {
					pop @groups;
					push @{ $groups[$i-1] }, @tmp;
					$flag = 1;
				# ...otherwise, merge with the next group
				} else {
					splice @groups, $i, 1;
					unshift @{ $groups[$i] }, @tmp;
					$flag = 1;
				}
			}
			$i++;
		}
	}
	
	TRACE(__PACKAGE__." merge: returns ".@groups." groups");
	return @groups;
}

sub find_groups {
	my $self = shift;

	# input checks
	foreach (@_) {
		if ($self->{'ItemDataKey'}) {
			croak("You must supply a list solely of hash references") unless (ref($_) eq 'HASH');
		} else {
			croak("You must supply a list solely of scalars") if ref($_);
		}
	}
	croak("You must supply a list of at least one item") unless @_;

	my @items = $self->_sort(@_);

	my $sz = $self->{'MinSetSize'};
	my $maxgroups = int( @items / $sz );
	TRACE(__PACKAGE__." find_groups: will divide into at most $maxgroups");
	
	# some cases where we know we can return immediately
	if ($maxgroups < 2) {
		return (\@items);
	}
	if (@items < 2) {
		return (\@items);
	}

	my $range;
	if ($self->{'ItemDataKey'}) {
		$range = $items[-1]{ $self->{'ItemDataKey'} } - $items[0]{ $self->{'ItemDataKey'} };
	} else {
		$range = $items[-1] - $items[0];
	}
	TRACE(__PACKAGE__." find_groups: range is $range");
	if ($range <= 0) {
		return (\@items);
	}

	my @splitpoints;
	if ($self->{'MaxGroups'} && $maxgroups > $self->{'MaxGroups'}) {
		$maxgroups = $self->{'MaxGroups'};
	}
	for my $n (2..$maxgroups) {
		my $thresh = $self->{'GroupSeparationFactor'} * $range/$n;
		TRACE(__PACKAGE__." find_groups: attempting to split into $n groups, threshold $thresh");
		
		@splitpoints = ();
		for my $i (1..$#items) {
			my $diff;

			if ($self->{'ItemDataKey'}) {
				$diff = $items[$i]{ $self->{'ItemDataKey'} } - $items[$i-1]{ $self->{'ItemDataKey'} };
			} else {
				$diff = $items[$i] - $items[$i-1];
			}
			if ($diff >= $thresh) {
				TRACE(__PACKAGE__." find_groups: found splitpoint before index $i");
				push @splitpoints, $i;
			}
		}
		while (@splitpoints >= $n) {
			pop @splitpoints;
		}
		if (@splitpoints && (@splitpoints == $n-1)) {
			last;
		} else {
			@splitpoints = ();
		}

		# otherwise, continue to next number of groups
	}

	# unable to split the items up
	if (! @splitpoints) {
		return (\@items);
	}
	
	TRACE(__PACKAGE__." find_groups: Found these splitpoints: ".join(', ', @splitpoints));
	my @groups;
	foreach my $p (reverse @splitpoints) {
		my @newgroup = splice @items, $p;
		unshift @groups, \@newgroup;
	}
	if (@items) {
		unshift @groups, \@items;
	}
	return $self->merge_small_sets(@groups);
}

sub _sort {
	my $self = shift;
	my @items;

	if ($self->{'ItemDataKey'}) {
		@items = sort { $a->{ $self->{'ItemDataKey'} } <=> $b->{ $self->{'ItemDataKey'} } } @_;
	} else {
		@items = sort { $a <=> $b } @_;
	}

	return @items;
}

sub TRACE {}
sub DUMP {}

=head1 NAME

Set::Partition::SimilarValues - Divide a set of items into smaller sets with similar, or clustered, values

=head1 DESCRIPTION

This module can be used to divide a set of numerical values - or hashes where a certain
key is a numerical value - into subgroups where the values are similar, or close together.

Example: we have the set of values I<{ 5, 5, 5, 5, 45, 50, 60 }>

We can look at that list and see that there are two subsets of clustered values;
it's like a bimodal distribution.

The two subsets are: I<{5, 5, 5, 5}> and I<{45, 50, 60}>

This module can handle lists of scalar values:

	@values = (5, 5, 5, 5, 45, 50, 60);

or lists of hashes where the value is in a specified key:

	@values = (
		{ grid_ref_x => 5, foo => 'bar' },
		{ grid_ref_x => 45, bax => 'qux' },
		# etc. with other values of 'grid_ref_x'
	);

This module tries to identify such clusters of values and attempts to split
your original set into subsets of more close-together values. See L</ALGORITHM>
for details on how this is achieved.

=head1 SYNOPSIS

	my $o = new Set::Partition::SimilarValues();
	my @rv = $o->find_groups(45,5,50,5,5,60,60,5);
	# @rv is ([5,5,5,5], [45,50,60,60])
	
	@rv = $o->find_groups(1,1,1,1,1);
	# @rv is ([1,1,1,1,1])
	
	@rv = $o->merge_small_sets([1],[2,3,4,5,6]);
	# @rv is ([1,2,3,4,5,6])
	
	$o = new Set::Partition::SimilarValues( ItemDataKey => 'foo' );
	@rv = $o->find_groups(
		{ foo => 42, bar => 'baz' },
		{ foo => 12, qux => '942' },
		{ foo => 1,  spam => { more => 'data' } },
		# etc. for other hashes of data
	);
	# @rv will be something like:
	#   ( [{ foo => 1, spam => { more => 'data' } }, { foo => 2 }], [{ foo => 11 },{ foo => 12, qux => '942' }], ... )

=head1 METHODS

=over 4

=item new( %options )

Class method. Makes a new object. Dies if there are problems with any supplied options.
See L</CONSTRUCTOR OPTIONS> for options.

=item find_groups( @list_of_items )

Object method. Takes in a list of one or more items. If the ItemDataKey constructor option is
used then the items will be hash references, otherwise they will simply be scalar
values. The items are sorted and then it tries to find clusters of values.
The method returns one or more array references, each array containing a subset of
the input items.

Note that this routine sorts the items before use, so you may supply them in
any order.

=item merge_small_sets( @list_of_array_references )

Object method. Takes in one or more references to arrays, or sets, of items. If any set is smaller
than the MinSetSize value it is merged with the next set, i.e. the one at the next
index position in the list of array references. If the last set is undersized it
is merged with the set before it.

=back

=head1 CONSTRUCTOR OPTIONS

All of these are optional.

=over 4

=item MinSetSize

Specify that any subsets found contain at least this many items.
Depending on the size of your data set, you may wish to adjust this.
Default is 3.

=item GroupSeparationFactor

Generally you won't need to adjust this.
The algorithm looks for large jumps from one value to the next - if the difference
is greater than a threshold then it means that this is a boundary between subsets.
The threshold is: C<GroupSeparationFactor * (HighestValue - LowestValue ) / NumberOfGroups>.
This value can be used to tune the module's idea of "large".
Default is 1.0.

=item ItemDataKey

By default the items supplied to find_groups() are just numbers. If you want
to give it hashes of data, use this option to specify which key in the hash
contains the numerical value.

=item MaxGroups

If you want to limit the number of groups into which this module breaks
the list of items, set this value to the desired number. The module may well
generate fewer subsets than this value if it's set too low, so this is
probably of most use when you have large sets of items to divide.

=back

=head1 ALGORITHM

Refer back to the example in L</DESCRIPTION>. The code in find_groups() first
sorts the items. It then works out the maximum number of groups it can possibly generate
based on the MinSetSize value - simply C<int(NumberOfItems / MinSetSize)>.
It then works out the range of values, by subtracting the lowest from the highest.

Then it goes into a loop, starting at 2 and going up to the maximum number of groups.
It then works out a threshold, which is the size of jump between two values that
can be considered so large that it divides one subset from another. The threshold is
simply C<GroupSeparationFactor * Range / NumberOfGroups>. E.g. if our range is 90
and we're trying to divide into 2 sets, then a jump of 45 or more would indicate
that we've gone from one subset to another, because the jump is relatively large.

Looking at our example, the jump between the '5' and the '45' is 40, which is
large relative to the overall range of 55. Since the items are sorted, we know that
this can mark a transition from one subset to another.

If it fail to split the set into 2, it tries to split it into 3. So, if our
range is 90, then it will look for a difference of 30 between adjacent values.
The loop continues until it is either able to split the set up into the
required number of groups, or it reaches the maximum number of groups and gives up.

=head1 VERSION

$Revision: 1.3 $

=cut
