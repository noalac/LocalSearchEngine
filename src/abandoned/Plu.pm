package Plu;
# Author: noalac @ HUST, Dian Group, no.393

use strict;
use warnings;
use File::Find::Rule;
use Plucene::Document;
use Plucene::Document::Field;
use Plucene::Analysis::SimpleAnalyzer;
use Plucene::Index::Writer;
use Plucene::QueryParser;
use Plucene::Search::IndexSearcher;
use Plucene::Search::HitCollector;
use File::Spec qw(catpath);
use DBM::Deep;
use Split;
use HTML::TreeBuilder 5 -weak;
use CAM::PDF;

require Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);

$VERSION = '1.7';
# 1.0: Init release, do not support Chinese
# 1.1: Complete search and show results function
# 1.2: Now support multi file types...txt, htm etc.
# 1.3: Delete the original index data before rebuilding
# 1.4: Split the key words first then search
# 1.5: Parse htm/html file in better way
# 1.6: Keep the results unique to each other
# 1.7: Add pdf support

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

	join(' ', @content);
}

sub BuildContentIndex {
	my $rootdir = shift;
	my $optimiz = shift;

	# delete old content index
	chdir $condb;
	unlink <*>;
	chdir File::Spec->updir();

	print "Building Content Index...\n";

	my $analyzer = Plucene::Analysis::SimpleAnalyzer->new();
	my $writer = Plucene::Index::Writer->new($condb, $analyzer, 1);

	my @filetypes = qw(txt htm pdf);

	foreach my $type (@filetypes) {
		# find files based on file type
		my $rule = File::Find::Rule->new;
		$rule->file;
		$rule->name( qr/.*\.$type/i );   # ignore letter case
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

			# form a document
			my $doc = Plucene::Document->new;
			$doc->add(Plucene::Document::Field->Text(content => $content));
			$doc->add(Plucene::Document::Field->Keyword(filename => $file));

			# add document to index writer
			$writer->add_document($doc);

			undef $doc;
		}
		undef $rule;
	}

	# optimize if request to do it (optional really)
	$writer->optimize if $optimiz;

	# close
	undef $writer;

	$info{CONTENT} = time();

	print "Building Done!!\n";
	1;
}

sub SearchContentData {
	my $target = shift;
	my @results;

	my $parser = Plucene::QueryParser->new({
        analyzer => Plucene::Analysis::SimpleAnalyzer->new(),
        default  => "content" # Default field for non-specified queries
    });

	my @names = Split::NameSplit($target);

	foreach my $name (@names) {
		my $queryinfo = "content:\"$name\"";

		my $query = $parser->parse( $queryinfo );

		my $searcher = Plucene::Search::IndexSearcher->new($condb);

		my @docs;
		my $hc = Plucene::Search::HitCollector->new(
			collect => sub {
				my ($self, $doc, $score) = @_;
				push @docs, $searcher->doc($doc);
			}
		);

		$searcher->search_hc($query => $hc);

		# show results in debug
#		foreach my $doc (@docs) {
#			my $filename = $doc->get('filename')->string();
#			print "$filename\n";
#		}

		# collect filename results
		map{ push @results, $_->get('filename')->string() } @docs;
	}

	# keep the results unique
	my %tmp_hash = ();
	my @unique_results = grep { ++$tmp_hash{$_} < 2 } @results;

	# return results
	@unique_results;
}

1;


