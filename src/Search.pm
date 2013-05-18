package Search;
# Author: noalac @ HUST, Dian Group, no.393

use strict;
use warnings;
use Index;
use Split;
use DBM::Deep;

require Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);

$VERSION = '2.03';
# 1.0: Init release, simple search from database and return
# 1.1: Add PackWords subroutine to pre handle input keywords
# 1.2: PackWords support ',' and ' ' as separator
# 1.3: Add CalcScore subroutine to measure relativity of dirs
# 1.4: Now support word glob with ? and *
# 1.5: Upper dir's score will be added to lower files if match
# 1.6: Now support case sensitive search
# 1.7: Add include ALL/NOT option filter for search results
# 1.8: Handle special characters like / . + $ ^ | [] in input
# 1.9: Modify search score calc algorithms
# 1.10: Huge modify! bind database at selecting data, make it get
#           the latest information, and added a initialize subroutine
# 1.11: The FuzzySearchData is finished, with the meta thoughts
# 2.00: Get the dbm name and  total dbm number from Index module
# 2.01: Modify as the Index module has changed completely
# 2.02: Add a patch to enable glob ^ and $
#          All glob will take influence in include all/not
# 2.03: Add StrictSearchData subroutine

@ISA = qw(Exporter);
@EXPORT = qw(SearchData FuzzySearchData StrictSearchData);
@EXPORT_OK = qw();

# tie db-info to use the TOTALNUM
tie my %dbinfo, "DBM::Deep", "db-info";

sub PackWords {
    my $word = shift;

    return () if $word eq "";

    # check \ / . + $ ^ | []
    $word =~ s/([.+\$\^\/\|\[\]\\])/\\$1/g;

    my @packed_words = ($word =~ /{.*?}/g);
	# delete packed words from original
    map {$word =~ s/$_//} @packed_words;
    $word =~ s/^\s*|\s*$|^,*|,*$//;
    $word =~ s/[{}]//g;
    map { s/\s*[{}]\s*//g } @packed_words;

	# words can be divided by , and space
    foreach ( split /[,\s]+/, $word ) { push(@packed_words, $_) }

    @packed_words;
}

sub Glob {
    my $word = shift;

    # glob symbol
    $word =~ s/\?/./g;
    $word =~ s/\*/.+/g;

    # return
    $word;
}

sub CheckGlob {
	# return 0 if pass the check
	# return 1 or more if fail to pass
	my $glob_word = shift;
	my $dir = shift;
	my $case = shift;

	# if there is only . or .* return fail immediately
	return 1 if $glob_word =~ /^[.\*]*$/;

	# the default value is pass
	my $ret = 0;

	# recover ^ and $ glob
	if ($glob_word =~ /\^|\$/) {
		$glob_word =~ s/\\\^/^/g;
		$glob_word =~ s/\\\$/\$/g;
		my ($vol, $path, $file) = File::Spec->splitpath($dir);
		$ret++ unless ($file =~ /$glob_word/i);
		# no need to care case here
	} else {
		$glob_word =~ s/\\\^|\\\$//g;
		# basic check
		if ($case) {
			$ret++  unless ($dir =~ /$glob_word/)
		} else {
			$ret++ unless ($dir =~ /$glob_word/i)
		}
	}

	# if pass return 0
	return $ret;
}

sub CalcScore {
    my $ratio = shift;
    my $num = shift;
    my $freq = shift;

	# core function
    my $score = ( $freq * log($dbinfo{TOTALNUM}/$num) ) * $ratio;

    $score;
}

sub SelectData {
    my $target = shift;
    my $glob_word = shift;
    my $case_sen = shift;

	# choose one of the several databases
	# this will reduce lots of searching time
	my $db_name = Index::GetDataBase($target);
	tie my %db, "DBM::Deep", $Index::bindb{$db_name} or
	  die "ERROR: Cannot read database...\n";

	my @dbkey = keys %db;

    # data hash contains results
    my %data = ();

    foreach (@dbkey) {
		if (/^$target/) {
			my $tmprat = length($target) / length($_);
			my %tmphash = %{ $db{$_} };
			my $tmpnum = scalar(keys %tmphash);

			# filter with glob word
			foreach my $tmpdir (keys %tmphash) {

				# check glob words, return 0 if pass!!
				next if (CheckGlob($glob_word, $tmpdir, $case_sen));

				# give score to each dir
				$data{$tmpdir} =
				  CalcScore($tmprat, $tmpnum, $tmphash{$tmpdir})

#					  CalcScore($tmprat, $tmpnum, $tmphash{$tmpdir})
#						if $tmpdir =~ /$glob_word/i;
			}
		}
    }
    #return hash result contains each dir and score
    %data;
}

sub MergeDir {
    my $hash_ref = shift;
    my %rsthash = %{ $hash_ref };
    my %result = ();

    foreach (keys %rsthash) {
		my %dirhash = %{ $rsthash{$_} };
		foreach my $dir (keys %dirhash) {
			if ($result{$dir}) {
				# dir exist before
				$result{$dir} += $dirhash{$dir};
			} else {
				# new dir
				$result{$dir} = $dirhash{$dir};
			}
		}
    }

    # return merge result
    %result;
}

sub SearchData {
    # pre process
    my %match = ();
    my @words_any = PackWords(shift);
    $match{'ANY'} = \@words_any;
    my @words_all  = PackWords(shift);
    $match{'ALL'}  = \@words_all;
    my @words_not  = PackWords(shift);
    $match{'NOT'}  = \@words_not;

    my $case_sen = shift;

    # clear last search result
    my %result = ();

    # searching key words MUST exist
    foreach my $word ( @{$match{'ANY'}} ) {

		# tmp_result contain result of several names in one word
		my %tmp_result = ();
		# glob_word contain one word converted into glob style
		my $glob_word = Glob($word);
		# names contain names after spliting

		foreach my $name ( Split::NameSplit($word) ) {
			# tmp_hash contaions dir and score for one name
			my %tmp_hash = SelectData($name, $glob_word, $case_sen);

			$tmp_result{$name} = \%tmp_hash;
		}

		# merge dir and score for one word
		my %merged_rst = MergeDir(\%tmp_result);
		$result{$word} = \%merged_rst;
		# consider what if user inputs "123 123"
    }

    my %merged_result = MergeDir(\%result);

    # IMPORTANT! add upper dir's score (as 1 of former upper dir score)
    my $alpha = 1;
    foreach my $cur_dir (keys %merged_result) {
		my ($volume, $upper_dir, $file) = File::Spec->splitpath($cur_dir);
		$upper_dir =~ s/\/$//;
		$merged_result{$cur_dir} += $alpha * $merged_result{$upper_dir}
		  if $merged_result{$upper_dir};
	}

    # include ALL filter
    foreach my $dir (keys %merged_result) {
		foreach ( @{$match{'ALL'}} ) {
			my $all_word = Glob($_);

			# check glob words, return 0 if pass!!
			delete $merged_result{$dir}
			  if (CheckGlob($all_word, $dir, $case_sen));
		}
    }

    # include NOT filter
    foreach my $dir (keys %merged_result) {
		foreach ( @{$match{'NOT'}} ) {
			my $not_word = Glob($_);

			# check glob words, return 0 if pass!!
			delete $merged_result{$dir}
			  unless (CheckGlob($not_word, $dir, $case_sen));
		}
    }

    %merged_result;
}

sub MetaProc {
	# make the keywords as meta elements
	my $word = shift;

	my @meta_result = ();

	my @chinese = ($word =~ /[^\x00-\x7f]+/g);
	foreach (@chinese) {
		# three characters makes a Chinese word
		s/([\x80-\xFF]{3})/$1 /g;
		push @meta_result, $_;
	}

	my @english = ($word =~ /[a-zA-Z']+/g);
	foreach (@english) {
		s/'.*//;
		# IMPORTANT!! if the rest of string is 1 then leave it away
		if (/s$|r$|ing$|ed$|en$/i) {
			s/s$|r$|ing$|ed$|en$//i if (length($&)+1 < length($_));
		}
		push @meta_result, $_;
	}

	my @number = ($word =~ /[0-9]+/g);
	push @meta_result, @number;

	join " ", @meta_result;
}

sub FuzzySearchData {
	my @words = PackWords(shift);

	my @meta_input = ();
	foreach my $word (@words) {
		push @meta_input, MetaProc($word);
	}

    # clear last search result
    my %result = ();

	# similar with SearchData
    foreach my $word ( @meta_input ) {
		my %tmp_result = ();
		my $glob_word = Glob($word);

		foreach my $name ( Split::NameSplit($word) ) {
			my %data = ();

			# This is the difference!! choose one KIND of database instead of one
			foreach my $db_name (Index::GetDataBaseKind($name)) {
				tie my %db, "DBM::Deep", $Index::bindb{$db_name} or
				  die "ERROR: Cannot read database...\n";

				my @dbkey = keys %db;

				foreach (@dbkey) {
					if (/$name/) {
						my $tmprat = length($name) / length($_);
						my %tmphash = %{ $db{$_} };
						my $tmpnum = scalar(keys %tmphash);

						# filter with glob word
						foreach my $tmpdir (keys %tmphash) {

							# another difference, do not check glob words at all!

							# give score to each dir
							$data{$tmpdir} =
							  CalcScore($tmprat, $tmpnum, $tmphash{$tmpdir});
						  }
					}
				}
			}

			$tmp_result{$name} = \%data;
		}

		my %merged_rst = MergeDir(\%tmp_result);
		$result{$word} = \%merged_rst;
    }

    my %merged_result = MergeDir(\%result);

    # IMPORTANT! add upper dir's score (as 1 of former upper dir score)
    my $alpha = 1;
    foreach my $cur_dir (keys %merged_result) {
		my ($volume, $upper_dir, $file) = File::Spec->splitpath($cur_dir);
		$upper_dir =~ s/\/$//;
		$merged_result{$cur_dir} += $alpha * $merged_result{$upper_dir}
		  if $merged_result{$upper_dir};
	}

    %merged_result;
}

sub StrictSearchData {
    # pre process
    my @words_any = PackWords(shift);
    my @words_all  = PackWords(shift);
    my @words_not  = PackWords(shift);
    my $case_sen = shift;

    # clear last search result
    my %result = ();

    # searching key words MUST exist
    foreach my $word ( @words_any ) {

		# tmp_result contain result of several names in one word
		my %tmp_result = ();

		# glob_word contain one word converted into glob style
		my $glob_word = Glob($word);
		# names contain names after spliting

		foreach my $name ( Split::NameSplit($word) ) {

			# choose one of the several databases
			# this will reduce lots of searching time
			my $db_name = Index::GetDataBase($name);
			tie my %db, "DBM::Deep", $Index::bindb{$db_name} or
			  die "ERROR: Cannot read database...\n";

			# get results directly, skip if doesn't exist
			next unless (defined($db{$name}));

			my %tmp_hash = %{ $db{$name} };
			$tmp_result{$name} = \%tmp_hash;
		}

		# merge dir and score for one word, the score now is word frequency
		my %merged_rst = MergeDir(\%tmp_result);
		$result{$word} = \%merged_rst;
		# consider what if user inputs "123 123"
    }

    my %merged_result = MergeDir(\%result);

    # IMPORTANT! add upper dir's score (as 1 of former upper dir score)
    my $alpha = 0.5;
    foreach my $cur_dir (keys %merged_result) {
		my ($volume, $upper_dir, $file) = File::Spec->splitpath($cur_dir);
		$upper_dir =~ s/\/$//;
		$merged_result{$cur_dir} += $alpha * $merged_result{$upper_dir}
		  if $merged_result{$upper_dir};
	}

    # include ALL filter
    foreach my $dir (keys %merged_result) {
		foreach ( @words_all ) {
			my $all_word = Glob($_);

			# check glob words, return 0 if pass!!
			delete $merged_result{$dir}
			  if (CheckGlob($all_word, $dir, $case_sen));
		}
    }

    # include NOT filter
    foreach my $dir (keys %merged_result) {
		foreach ( @words_not ) {
			my $not_word = Glob($_);

			# check glob words, return 0 if pass!!
			delete $merged_result{$dir}
			  unless (CheckGlob($not_word, $dir, $case_sen));
		}
    }

    %merged_result;
}


sub RegexpSearchData {
	my $name = shift;

    # clear last search result
    my %result = ();

	# This is the difference!! choose one KIND of database instead of one
	foreach my $db_name (Index::GetDataBaseAll()) {
		tie my %db, "DBM::Deep", $Index::bindb{$db_name} or
		  die "ERROR: Cannot read database...\n";

		my @dbkey = keys %db;

		foreach (@dbkey) {
			if (/$name/) {
				my %tmphash = %{ $db{$_} };
				foreach my $tmpkey (keys %tmphash) {
					$result{$tmpkey} = 1;
				}
			}
		}
	}

    %result;
}

1;

