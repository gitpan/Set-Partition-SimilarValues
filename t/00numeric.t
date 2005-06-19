#!/usr/local/bin/perl
use strict;
use Test::Assertions qw(test);

# When run with "make test", the environment should set up correctly.
use Set::Partition::SimilarValues;

# Trivial command-line options, and we don't require that
# users have Log::Trace - it's useful for me during development though

my $trace = 0;
if (@ARGV && $ARGV[0] eq '-t') {
	eval "require Log::Trace; import Log::Trace 'print';";
} elsif (@ARGV && $ARGV[0] eq '-T') {
	eval "require Log::Trace; import Log::Trace 'print' => { Deep => 1 };";
}

plan tests;

#######################################################################
ASSERT($Set::Partition::SimilarValues::VERSION, "Loaded version $Set::Partition::SimilarValues::VERSION");

eval { my $bad = new Set::Partition::SimilarValues( MinSetSize => 0 ); };
chomp($@);
ASSERT($@, "Error trapped: $@");

eval { my $bad = new Set::Partition::SimilarValues( MinSetSize => -2 ); };
chomp($@);
ASSERT($@, "Error trapped: $@");

eval { my $bad = new Set::Partition::SimilarValues( MinSetSize => 3.4 ); };
chomp($@);
ASSERT($@, "Error trapped: $@");

eval { my $bad = new Set::Partition::SimilarValues( GroupSeparationFactor => 0 ); };
chomp($@);
ASSERT($@, "Error trapped: $@");

eval { my $bad = new Set::Partition::SimilarValues( GroupSeparationFactor => -0.5 ); };
chomp($@);
ASSERT($@, "Error trapped: $@");

eval { my $bad = new Set::Partition::SimilarValues( MaxGroups => 1 ); };
chomp($@);
ASSERT($@, "Error trapped: $@");

eval { my $bad = new Set::Partition::SimilarValues( MaxGroups => 4.1 ); };
chomp($@);
ASSERT($@, "Error trapped: $@");


my $o = new Set::Partition::SimilarValues();
ASSERT($o, "created object");


#######################################################################
# cases where sets do not get merged
my @rv = $o->merge_small_sets();
ASSERT(EQUAL(\@rv, []), "empty set returned");

@rv = $o->merge_small_sets([]);
ASSERT(EQUAL(\@rv, [[]]), "set of an empty set returned");

@rv = $o->merge_small_sets([1]);
ASSERT(EQUAL(\@rv, [[1]]), "single small set returned");

@rv = $o->merge_small_sets([1,2,3,4,5,6]);
ASSERT(EQUAL(\@rv, [[1,2,3,4,5,6]]), "single set over threshold returned");

@rv = $o->merge_small_sets([1,2,3,4,5,6], [7,8,9], [10,11,12,13]);
ASSERT(EQUAL(\@rv, [[1,2,3,4,5,6], [7,8,9], [10,11,12,13]]), "three sets not merged");


#######################################################################
# test cases where sets do merge
@rv = $o->merge_small_sets([1],[2,3,4,5,6]);
ASSERT(EQUAL(\@rv, [[1,2,3,4,5,6]]), "two sets merged");

@rv = $o->merge_small_sets([1,2,3,4,5],[6]);
ASSERT(EQUAL(\@rv, [[1,2,3,4,5,6]]), "two sets merged");

@rv = $o->merge_small_sets([1,2,3,4],[5],[6,7,8,9]);
ASSERT(EQUAL(\@rv, [[1,2,3,4],[5,6,7,8,9]]), "three sets, two merged");

@rv = $o->merge_small_sets([1],[2],[3],[4],[5],[6],[7],[8]);
ASSERT(EQUAL(\@rv, [[1,2,3,4],[5,6,7,8]]), "all sets");

@rv = $o->merge_small_sets([],[],[],[],[],[],[],[]);
ASSERT(EQUAL(\@rv, [[]]), "all empty sets");


#######################################################################
# change minimum set size
$o = new Set::Partition::SimilarValues(
	MinSetSize => 4,
);
ASSERT($o, "created object");

@rv = $o->merge_small_sets([1,2,3],[4,5,6]);
ASSERT(EQUAL(\@rv, [[1,2,3,4,5,6]]), "two sets merged");

@rv = $o->merge_small_sets([1,2,3,4,5,6], [7,8,9,10,11,12,13]);
ASSERT(EQUAL(\@rv, [[1,2,3,4,5,6], [7,8,9,10,11,12,13]]), "three sets merged");


#######################################################################
# test the sorting routine

@rv = $o->_sort();
ASSERT(EQUAL(\@rv, []), "sort ok");

@rv = $o->_sort(1);
ASSERT(EQUAL(\@rv, [1]), "sort ok");

@rv = $o->_sort(2,5,4,6,1,3);
ASSERT(EQUAL(\@rv, [1,2,3,4,5,6]), "sort ok");


$o = new Set::Partition::SimilarValues(
	ItemDataKey => 'foo',
);

@rv = $o->_sort();
ASSERT(EQUAL(\@rv, []), "sort hashes ok");

@rv = $o->_sort({ foo => 1 });
ASSERT(EQUAL(\@rv, [{ foo => 1 }]), "sort hashes ok");

@rv = $o->_sort({ foo => 2 }, { foo => 5 }, { foo => 4 }, { foo => 6 }, { foo => 1 }, { foo => 3 });
ASSERT(EQUAL(\@rv, [
	{ foo => 1 }, { foo => 2 }, { foo => 3 }, { foo => 4 }, { foo => 5 }, { foo => 6 }
]), "sort hashes ok");


#######################################################################
# now, test the main routine itself
# first with scalars
$o = new Set::Partition::SimilarValues(
	MinSetSize => 2,
);

# check error conditions
eval {
	$o->merge_small_sets(1,2,3);
};
chomp($@);
ASSERT($@, "Error trapped: $@");

eval {
	$o->find_groups(1,[],3);
};
chomp($@);
ASSERT($@, "Error trapped: $@");

eval {
	$o->find_groups();
};
chomp($@);
ASSERT($@, "Error trapped: $@");

eval {
	$o->find_groups({ foo => 1 });
};
chomp($@);
ASSERT($@, "Error trapped: $@");

@rv = $o->find_groups(1);
ASSERT(EQUAL(\@rv, [[1]]), "1 element set in, 1 element set out");

@rv = $o->find_groups(0,1,2,45,60,75,90);
ASSERT(EQUAL(\@rv, [[0,1,2,45,60,75,90]]), "one gap, not two, big enough for 3-group split");

@rv = $o->find_groups(1,1,1,1,1,1,1);
ASSERT(EQUAL(\@rv, [[1,1,1,1,1,1,1]]), "Set with no range");

@rv = $o->find_groups(45,5,50,5,5,60,60,5);
ASSERT(EQUAL(\@rv, [[5,5,5,5],[45,50,60,60]]), "Set split into 2 ranges");

@rv = $o->find_groups(-2,2);
ASSERT(EQUAL(\@rv, [[-2,2]]), "Too small to split");

@rv = $o->find_groups(1,2,3,4);
ASSERT(EQUAL(\@rv, [[1,2,3,4]]), "Can't be split");

@rv = $o->find_groups(1,2,11,12,21,22);
ASSERT(EQUAL(\@rv, [[1,2],[11,12],[21,22]]), "Set split into 3 ranges");

@rv = $o->find_groups(32,1,2,31,11,12,21,22);
ASSERT(EQUAL(\@rv, [[1,2],[11,12],[21,22],[31,32]]), "Set split into 4 ranges");

@rv = $o->find_groups(42,32,1,2,31,41,11,12,21,22);
ASSERT(EQUAL(\@rv, [[1,2],[11,12],[21,22],[31,32],[41,42]]), "Set split into 5 ranges");


$o->{'MaxGroups'} = 3;

@rv = $o->find_groups(42,32,1,2,31,41,11,12,21,22);
ASSERT(EQUAL(\@rv, [[1,2,11,12,21,22,31,32,41,42]]), "Set not split with MG set");

@rv = $o->find_groups(1,1,2,3,4,5,6,7,8,9,10);
ASSERT(EQUAL(\@rv, [[1,1,2,3,4,5,6,7,8,9,10]]), "Set not split");

@rv = $o->find_groups(1,3,7,10);
ASSERT(EQUAL(\@rv, [[1,3,7,10]]), "Can't be split");


$o->{'GroupSeparationFactor'} = 0.6;

@rv = $o->find_groups(1,3,7,10);
ASSERT(EQUAL(\@rv, [[1,3],[7,10]]), "Can be split with GSF set");


$o = new Set::Partition::SimilarValues(
	MinSetSize => 5,
);
@rv = $o->find_groups(45,5,50,5,5,60,60,5);
ASSERT(EQUAL(\@rv, [[5,5,5,5,45,50,60,60]]), "Set not split ranges");

@rv = $o->find_groups(45,5,50,5,60,5,5,60,60,5);
ASSERT(EQUAL(\@rv, [[5,5,5,5,5],[45,50,60,60,60]]), "Set split into 2 ranges");

#######################################################################
# now test with hashes

$o = new Set::Partition::SimilarValues(
	ItemDataKey => 'foo',
	MinSetSize => 2,
);

eval {
	$o->find_groups();
};
chomp($@);
ASSERT($@, "Error trapped: $@");

eval {
	$o->find_groups(1);
};
chomp($@);
ASSERT($@, "Error trapped: $@");

@rv = $o->find_groups({ foo => 1 });
ASSERT(EQUAL(\@rv, [[{ foo => 1 }]]), "1 element set in, 1 element set out");

@rv = $o->find_groups({ foo => 5 },{ foo => 60 },{ foo => 5 },{ foo => 5 },{ foo => 45, more => 'data' },{ foo => 60 },{ foo => 5 });
ASSERT(EQUAL(\@rv, [[{ foo => 5 },{ foo => 5 },{ foo => 5 },{ foo => 5 }],[{ foo => 45, more => 'data' },{ foo => 60 },{ foo => 60 }]]), "Set split into 2");


@rv = $o->find_groups(
	{ foo => 42 },
	{ foo => 32 },
	{ foo => 1 },
	{ foo => 2 },
	{ foo => 31 },
	{ foo => 41, bar => 'baz' },
	{ foo => 11, qux => { more => 42 } },
	{ foo => 12 },
	{ foo => 21 },
	{ foo => 22 },
);
ASSERT(EQUAL(\@rv, [
[	{ foo => 1 },
	{ foo => 2 }],
[	{ foo => 11, qux => { more => 42 } },
	{ foo => 12 }],
[	{ foo => 21 },
	{ foo => 22 }],
[	{ foo => 31 },
	{ foo => 32 }],
[	{ foo => 41, bar => 'baz' },
	{ foo => 42 }],
]), "Set split into 5 ranges");


#######################################################################
# subroutines

sub TRACE {}
sub DUMP {}
