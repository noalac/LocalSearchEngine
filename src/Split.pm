package Split;
# Author: noalac @ HUST, Dian Group, no.393

use strict;
use warnings;

require Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);

$VERSION = '1.5';
# 1.0: Init release, only support English and numbers
# 1.1: Add support for Chinese words
# 1.2: Support for ignoring extend file type
# 1.3: Split words now support Chinese English and numbers
# 1.4: Support deleting filter words in English spliting
# 1.5: Support deleting the Chinese symbols

@ISA = qw(Exporter);
@EXPORT = qw(NameSplit);
@EXPORT_OK = qw();

# these are meaningless words
my @stop_words = qw (
be being been is was are were am do does did done will shall would should could can must may might
);

sub NameSplit {
	# receive & handle the first arguments
	my $name = shift;
	warn "WARN: Ignoring surplus arguments...\n" if @_;

	my @splited_names = ();

	# ignoring extend file type on Windows
	# have done in Index.pm
#	$name =~ s/\.\s*[0-9a-zA-Z]+\s*$// if $^O =~ /win/i;

	# Number part
	my @number = ($name =~ /[0-9]+/g);
	map{ push(@splited_names, NUMsplit($_)) } @number;

	# English and number part
	my @english = ($name =~ /[a-zA-Z']+/g);
	map{ push(@splited_names, ENGsplit($_)) } @english;

	# Chinese part
	my @chinese = ($name =~ /[^\x00-\x7f]+/g);
	map{ push(@splited_names, CHNsplit($_)) } @chinese;

	# make the names unique to each other
	# delete reduplicate key words
	my %tmp_hash = ();
	my @unique_names = grep { ++$tmp_hash{$_} < 2 } @splited_names;

	# return value based on type
	if (wantarray) {
		# return the array of spilted names
		sort @unique_names;
	} else {
		# return the number of splited names
		@unique_names + 0;
	}
}

sub NUMsplit {
	my $num = shift;

	# delete zero in the front
    $num =~ s/^0+([1-9])/$1/;
	$num =~ s/^0+$/0/;
	return $num;
}

sub ENGsplit {
	my $str = shift;

	# delete n't
	$str =~ s/(.*)n't/$1/g;

	my @rets = ();

	# split by '
	my @strs = split /'/, $str;
	foreach my $one_str (@strs) {
		# leaves the short fragment
#		warn "$one_str\n" if 1 >= length($one_str);
#		next if 1 >= length($one_str);

		if ($one_str =~ /[a-z][A-Z]/) {
			my @more_strs = ($one_str =~ /[A-Z][a-z]*/g);
			# IMPORTANT!! this is necessary for the first letter is lower case
		    map {$one_str =~ s/$_//} @more_strs;
			push @more_strs, $one_str unless "" eq $one_str;
			push @rets, @more_strs;
		} else {
			push @rets, $one_str;
		}
	}

	# lower case all letters
	map{ $_ = lc($_) } @rets;

	# IMPORTANT!! the returning will be pushed into an array
#	if ($str eq "") {
#		return ();
#	} else {
#		return $str;
#	}
	# return an array instead
	@rets;
}

sub CHNsplit {
	my $str = shift;
	my $filter_chn = "";

	if ($^O =~ /win/i) {
		# on Windows GBK encoding
		$filter_chn = "£®|£©|°£|£¨|£ª|°¢|£°|£ø|£∫|°Æ|°Ø|°∞|°±|°≠°≠|°™°™|£§|°∫|°ª|°æ|°ø";
	} else {
		# on Unix UTF-8 encoding
		$filter_chn = "Ôºà|Ôºâ|„ÄÇ|Ôºå|Ôºõ|„ÄÅ|ÔºÅ|Ôºü|Ôºö|‚Äò|‚Äô|‚Äú|‚Äù|‚Ä¶‚Ä¶|‚Äî‚Äî|Ôø•|„Äé|„Äè|„Äê|„Äë";
	}

	# delete chinese symbols
	$str =~ s/$filter_chn//g;

	# return
	if ($str eq "") {
		return ();
	} else {
		return $str;
	}
}

1;


