#!/usr/bin/perl
use warnings;
use strict;
use Split;
use Index;
use Search;
use Data::Dumper qw(Dumper);
use DBM::Deep;

BEGIN { Index::LoadData() }

tie my %dbinfo, "DBM::Deep", "db-info";
my $testdir = $dbinfo{ROOTDIR};

# Command shell
my $input = '';
my $mode = 'SPECIFIC';
my $include_all = '';
my $include_not = '';
my $case = 0;

sub PreFix {
	my $pre = "$mode";
	if ($include_all) {
		$pre = "$pre-ALL($include_all)";
	}
	if ($include_not) {
		$pre = "$pre-NOT($include_not)";
	}
	if ($case) {
		$pre = "$pre-CASE_ON";
	} else {
		$pre = "$pre-CASE_OFF";
	}

	$pre;
}

while ($input ne '[quit]') {

	print PreFix(), ">> ";

	$input = <STDIN>;
	chomp($input);
	next if $input =~ /^\s*$/;

	# build-in commands
	if ($input =~ /^\s*\[rebuild\]\s*$/i) {
		Index::RebuildData($testdir);
		next;
	}

	if ($input =~ /^\s*\[case\s+(\w*)\s*\]\s*$/i) {
		if ($1 =~ /^on$/i) {
			$case = 1;
		} elsif ($1 =~ /^off$/i) {
			$case = 0;
		} else {
			print "Unknown Command: $input\n";
			print "Maybe you want to input [case on/off]\n";
		}
		next;
	}

	if ($input =~ /^\s*\[mode\s+(.*)\s*\]\s*$/i) {
		if ($1 =~ /^specific$/i) {
			$mode = 'SPECIFIC';
		} elsif ($1 =~ /^fuzzy$/i) {
			$mode = 'FUZZY';
		} else {
			print "Unknown Command: $input\n";
			print "Maybe you want to input [mode specific/fuzzy]\n";
		}
		next;
	}

	if ($input =~ /^\s*\[includeall\s+(.*)\]\s*$/i) {
		$include_all = $1;
		next;
	}

	if ($input =~ /^\s*\[includenot\s+(.*)\]\s*$/i) {
		$include_not = $1;
		next;
	}

	if ($input =~ /^\s*\[clear\]\s*$/i) {
		$include_not = '';
		$include_all = '';
		$case = 0;
		next;
	}

	my %result = ();

	if ($mode eq 'SPECIFIC') {
		%result = Search::SearchData($input, $include_all, $include_not, $case);
	} else {
		%result = Search::FuzzySearchData($input);
	}


    print Dumper ( \%result );

}

END { Index::StoreData() }


