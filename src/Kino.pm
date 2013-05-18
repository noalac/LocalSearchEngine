package Kino;
# Author: noalac @ HUST, Dian Group, no.393

use strict;
use warnings;
use File::Find::Rule;
use File::Spec qw(catpath);
use DBM::Deep;
use Split;
use HTML::TreeBuilder 5 -weak;
use CAM::PDF;
use KinoSearch1::InvIndexer;
use KinoSearch1::Analysis::PolyAnalyzer;
use KinoSearch1::Searcher;
use KinoSearch1::Analysis::PolyAnalyzer;

require Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);

$VERSION = '2.1';
# 1.0: Init release, do not support Chinese
# 1.1: Complete search and show results function
# 1.2: Now support multi file types...txt, htm etc.
# 1.3: Delete the original index data before rebuilding
# 1.4: Split the key words first then search
# 1.5: Parse htm/html file in better way
# 1.6: Keep the results unique to each other
# 1.7: Add pdf support
# 2.0: Switch from Plucene to KinoSearch, extremely fast!!
# 2.1: Bug fix, as the KinoSearch do not support Chinese

@ISA = qw(Exporter);
@EXPORT = qw(BuildContentIndex SearchContentData IsIndexExist);
@EXPORT_OK = qw();

my $condb = 'content-data';
tie my %info, "DBM::Deep", "db-info";

sub IsIndexExist {
	if (-e $condb) {
		return 1;
	} else {
		return 0;
	}
}

sub TxtIndex {
	my $file = shift;

	open my $fh, '<', $file or return; # process next one if failed
	my $content = join('', (<$fh>));
	close $fh;

	# pre process to content
	$content =~ s/\n|\s+/ /g;

	return $content;
}

sub HtmIndex {
	my $file = shift;
	my $root = HTML::TreeBuilder->new_from_file($file);
	return $root->guts()->as_text;
}

sub PdfIndex {
	my $file = shift;

	my @content = ();

	my $pdf = CAM::PDF->new("$file");
	foreach (1..$pdf->numPages()) {
		push @content, $pdf->getPageText($_);
	}

	join("\n", @content);
}

sub BuildContentIndex {
	my $rootdir = shift;
	my $not_index = shift;
	if ($not_index) {
		$not_index = join('|', split(/[,\s]+/, $not_index));
	} else {
		$not_index = 0;
	}

	# delete old content index
	if (-e $condb) {
		chdir $condb;
		unlink <*>;
		chdir File::Spec->updir();
	}

	print "Building Content Index...\n";

	my $analyzer
	  = KinoSearch1::Analysis::PolyAnalyzer->new( language => 'en' );

	my $invindexer = KinoSearch1::InvIndexer->new(
		invindex => "$condb",
		create   => 1,
		analyzer => $analyzer,
	);
	$invindexer->spec_field( 
		name  => 'title',
		boost => 3,
	);

	$invindexer->spec_field( name => 'bodytext' );

	my @filetypes = qw(txt htm pdf);

	foreach my $type (@filetypes) {
		# find files based on file type
		my $rule = File::Find::Rule->new;
		$rule->file;
		$rule->name( qr/^[\x00-\x7f]+\.$type/i );   # ignore letter case
		foreach my $file ( $rule->in($rootdir) ) {

			my $content;

			# choose different subroutine for different file type
			if ($type =~ /txt/i) {
				# txt
				$content = TxtIndex($file);
			} elsif ($type =~ /htm/i) {
				# html & htm
				$content = HtmIndex($file);
			} elsif ($type =~ /pdf/i) {
				$content = PdfIndex($file);
			} else {
				# default, just process next one
				next;
			}

			# do not support Chinese FOR NOW!!
			$content =~ s/[^\x00-\x7f]+/ /g;
			# skip empty file
			next if $content =~ /^\s*$/;
			# some file not index
			next if $not_index and $file =~ /$not_index/i;

warn "$file\n";

			my $doc = $invindexer->new_doc;

			$doc->set_value( title => $file );
			$doc->set_value( bodytext => $content );

			$invindexer->add_doc($doc);
		}
		undef $rule;
	}
	$invindexer->finish;

	1;
}

sub SearchContentData {
	my $target = shift;
	my @results;

	my $analyzer
	  = KinoSearch1::Analysis::PolyAnalyzer->new( language => 'en' );

	my @names = Split::NameSplit($target);

	foreach my $name (@names) {
		# delete Chinese parts not supported yet
		next if $name =~ /[^\x00-\x7f]/;

		my $searcher = KinoSearch1::Searcher->new(
			invindex => "$condb",
			analyzer => $analyzer,
		);

		my $hits = $searcher->search( query => "$name" );
		while ( my $hit = $hits->fetch_hit_hashref ) {
			push @results, $hit->{title};
		}
	}

	# keep the results unique
	my %tmp_hash = ();
	my @unique_results = grep { ++$tmp_hash{$_} < 2 } @results;

	# return results
	@unique_results;
}

1;


