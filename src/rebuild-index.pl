#!/usr/bin/perl
use warnings;
use strict;
use Index;
use DBM::Deep;
use Kino;
use File::Spec qw(catpath);

my $rebuild_dir = $ARGV[0];
my $target = $ARGV[1];
my $not_index = $ARGV[2];
#print "$rebuild_dir\n";
my %info = ();

# CDMT: Content Database Modify Time

# info file name
#my $dbinfo = 'db-info';
if (-e "db-info") {
	tie %info, "DBM::Deep", "db-info";
	# read old database info, may be partly changed
} else {
	# reset as default
	$info{ROOTDIR} = File::Spec->curdir();
	$info{MODTIME} = 0;
	$info{CONTENT} = 0;
	$info{TOTALNUM} = 0;
	$info{ALLKEY} = ();
}

##################

if ($target eq 'ALL') {
	Index::RebuildData($rebuild_dir, $not_index);
	Kino::BuildContentIndex($rebuild_dir, $not_index);
} elsif ($target eq 'FILE') {
	Index::RebuildData($rebuild_dir, $not_index);
} elsif ($target eq 'CONTENT') {
	Kino::BuildContentIndex($rebuild_dir, $not_index);
} else {
	return;
}

##################


END { Index::StoreData() }
