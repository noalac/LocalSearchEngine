package Net;
# Author: noalac @ HUST, Dian Group, no.393

use strict;
use warnings;
use HTML::TreeBuilder 5 -weak;

#binmode(STDOUT, ':encoding(utf8)');
require Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);

$VERSION = '1.0';
# 1.0: This is just an additional module for more information on Internet

@ISA = qw(Exporter);
@EXPORT = qw(BaiduIt YahooIt);
@EXPORT_OK = qw();

my $maxnum = 7;

sub BaiduIt {
	my $word = shift;
	my $url = "http://www.baidu.com/s?wd=$word";

	my $root = HTML::TreeBuilder->new_from_url($url);

	my @tables = $root->find_by_tag_name('table');

	my %net_result = ();
	my $num = 0;
	foreach my $table (@tables) {
		# the first table is linked to e.baidu.com
		unless ($num) {
			$num = 1;
			next;
		}

		# this grey background color shows that it is an ad
		if (defined( $table->attr('bgcolor'))
			  and $table->attr('bgcolor') eq '#f5f5f5') {
			next;
		}

		my @tag_a = $table->find_by_tag_name('a');

		my $key =  $tag_a[0]->as_text();
		last unless defined($key);

		# class is m shows that it is a baidu snapshot at the end
		if (defined($tag_a[$#tag_a]->attr('class'))
			  and $tag_a[$#tag_a]->attr('class') eq 'm' ) {
			$net_result{$key} = $tag_a[$#tag_a-1]->attr('href');
		} else {
			$net_result{$key} = $tag_a[$#tag_a]->attr('href');
		}

		last if ($maxnum+1) <= $num++;
	}

	%net_result;
}


sub YahooIt {
	my $word = shift;
	my $url = "http://www.yahoo.cn/s?q=$word";

	my $root = HTML::TreeBuilder->new_from_url($url);

	my @anchors = $root->find_by_tag_name('a');

	my %net_result = ();
	my $num = 0;
	# The first three anchors are for Yahoo photo and Yahoo news etc.
	foreach my $anchor (@anchors[3..$#anchors]) {
		$net_result{$anchor->as_text()} = $anchor->attr('href');

		last if $maxnum <= $num++;
	}

	%net_result;
}

1;
