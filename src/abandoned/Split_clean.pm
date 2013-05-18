package Split;
# Author: noalac @ HUST, Dian Group, no.393

use strict;
use warnings;
use Encode qw(encode decode);

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
my @filter_words = qw (
be being been is was are were am do does did done will shall would should could can must may might
);

sub NameSplit {
	# receive & handle the first arguments
	my $name = shift;
	warn "WARN: Ignoring surplus arguments...\n" if @_;

	my @splited_names = ();

	# ignoring extend file type on Windows
	# not good enough
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

	# return value based on type
	if (wantarray) {
		# return the array of spilted names
		sort @splited_names;
	} else {
		# return the number of splited names
		@splited_names + 0;
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
	$str =~ s/(.*)n't/$1/;
	# delete letters after '
	$str =~ s/(.*)'.*/$1/;

	# lower case all letters
	$str = lc($str);

	# delete filter words
	map{ $str =~ s/^$_$//; } @filter_words;

	if ($str eq "") {
		return ();
	} else {
		return $str;
	}
}

sub CHNsplit {
	my $str = shift;

	my $filter_chn = '（|）|。|，|；|、|！|？|：|‘|’|“|”|……|——|￥|『|』|【|】';

	if ($^O =~ /win/i) {
		# on Windows
		$filter_chn = encode('utf-8', decode('gb2312', $filter_chn));
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


