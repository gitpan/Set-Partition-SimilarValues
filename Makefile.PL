use ExtUtils::MakeMaker;

# $Id: Makefile.PL,v 1.2 2005/06/19 01:41:47 pkent Exp $

WriteMakefile(
	AUTHOR		=> 'P Kent (pause@selsyn.co.uk)',
	ABSTRACT	=> 'Divide a set of items into smaller sets with similar, or clustered, values',
	NAME		=> 'Set::Partition::SimilarValues',
	DISTNAME	=> 'Set-Partition-SimilarValues',
	dist		=> {
		COMPRESS	=> 'gzip',
		SUFFIX		=> '.gz',
	},
	VERSION_FROM	=> 'lib/Set/Partition/SimilarValues.pm',
	PREREQ_PM	=> {
		Test::Assertions => 0,
	},
);
