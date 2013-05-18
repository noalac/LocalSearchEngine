package Index;
# Author: noalac @ HUST, Dian Group, no.393

use strict;
use warnings;
use Split;
use DBM::Deep;
use Data::Dumper qw(Dumper);
use Digest::MD5 qw(md5_base64);
use File::Spec::Functions qw(catpath);
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
#use Encode qw(encode decode);

require Exporter;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);

$VERSION = '3.02';
# 1.00: Init release, only read and store data
# 1.01: Add ClearData subroutine
# 1.02: Add InitData subroutine, complete init-read-store-clear process
# 1.03: Provide database names available to outside
# 1.04: Big improvement! add data now available (hash of hash)
# 1.05: Finish the index database building, including zip file scan
# 1.06: Minor fix for directory scan in zip file
# 1.07: Minor fix for md5 file reading handle (if empty...)
# 1.08: Change tie database as local variables for flexible
# 1.09: Add RebuildData subroutine, support searching at the same time
# 1.10: Pay more attention to returning value (delete temp db etc)
# 1.11: Minor fix for database building logic and input arguments error
# 1.12: Big modify in AddData subroutine, it is more accurate now
# 1.13: Delete MergeName subroutine, will not use it in future
# 1.14: Bug fix, add "" to target file when detecting file type
# 1.15: Modify in rebuilding database --- On Windows OS,
#       will just clear old one and build, because permission denied.
# 1.16: Solve permission denied error on Windows OS...FINALLY...
#       but keep the scalar file handle for optimise, which result in
#       the rebuilding process difference remains
# 1.17: Huge modify! the rebuilded index data can now be stored
#       immediately into database and speed up exiting process
# 1.18: Now support indexing with audio's ID3 information
#          The ID3 information cannot be searched, but for giving scores
# 2.00: Performance improved, record the totalnumber as a special key
# 2.01: Compress the index data by unindex extend file name
# 2.02: Minor bug fix in deleting the temp database
# 3.00: Em ... how to say ... nearly rewrite all the codes ...
#          Now the index data has been divided into 7 parts like Voldemort,
#         which will increase the searching speed 7 times, all the databases
#         are packed into a single folder to make workspace more tidy.
#         Use anonymous hashes and a redirect hash to complete work nicely!
# 3.01: Add a new DBM file called db-info to record necessary databases'
#         information without ACTURALLY reading them all.
#         The db-file contains ROOTDIR, MODTIME, TOTALNUM, ALLKEY
#         beware that ALLKEY directs to an array reference
# 3.02: Bug fix, in sub StoreData, will check all the databases for the need of
#           changing, then decide whether to skip the rest process

@ISA = qw(Exporter);
@EXPORT = qw(LoadData StoreData RebuildData GetDataBase GetDataBaseKind GetDataBaseAll);
@EXPORT_OK = qw(%bindb);

# database basic info
tie my %info, "DBM::Deep", 'db-info';

# database and md5 checksum files' names
my @dbname =  qw (sftwo garvk cmbnq pieuj dlhxzy number fallback);
my $index_dir = "file-data";

our %bindb = ();
my %tmpdb = ();
my %txtdb = ();
my %md5file = ();
foreach  (@dbname) {
	$bindb{$_} = catpath(undef, $index_dir, "index-data-$_.db");
	$tmpdb{$_} = catpath(undef, $index_dir, "temp-data-$_.db");
	$txtdb{$_} = catpath(undef, $index_dir, "index-data-$_.txt");
	$md5file{$_} = catpath(undef, $index_dir, "md5checksum-$_");
}

my %db;

# Now don't need these massive ugly stuffs at all
#my $bindb_sftwo = "index-data-sftwo.db";
#my $bindb_garvk = "index-data-garvk.db";
#my $bindb_cmbnq = "index-data-cmbnq.db";
#my $bindb_pieuj = "index-data-pieuj.db";
#my $bindb_dlhxzy = "index-data-dlhxzy.db";
#my $bindb_number = "index-data-number.db";
#my $bindb_fallback = "index-data-fallback.db";

#my $tmpdb_sftwo = "temp-data-sftwo.db";
#my $tmpdb_garvk = "temp-data-garvk.db";
#my $tmpdb_cmbnq = "temp-data-cmbnq.db";
#my $tmpdb_pieuj = "temp-data-pieuj.db";
#my $tmpdb_dlhxzy = "temp-data-dlhxzy.db";
#my $tmpdb_number = "temp-data-number.db";
#my $tmpdb_fallback = "temp-data-fallback.db";
#
#my $txtdb_sftwo = "index-data-sftwo.txt";
#my $txtdb_garvk = "index-data-garvk.txt";
#my $txtdb_cmbnq = "index-data-cmbnq.txt";
#my $txtdb_pieuj = "index-data-pieuj.txt";
#my $txtdb_dlhxzy = "index-data-dlhxzy.txt";
#my $txtdb_number = "index-data-number.txt";
#my $txtdb_fallback = "index-data-fallback.txt";
#
#my $md5file_sftwo = "md5checksum-sftwo";
#my $md5file_garvk = "md5checksum-garvk";
#my $md5file_cmbnq = "md5checksum-cmbnq";
#my $md5file_pieuj = "md5checksum-pieuj";
#my $md5file_dlhxzy = "md5checksum-dlhxzy";
#my $md5file_number = "md5checksum-number";
#my $md5file_fallback = "md5checksum-fallback";
#

# redirect hash
# It will tell which database a key should go to
my %redirect = (
	g => 'garvk',
	a  => 'garvk',
	r => 'garvk',
	v  => 'garvk',
	k => 'garvk',

	c => 'cmbnq',
	m => 'cmbnq',
	b => 'cmbnq',
	n => 'cmbnq',
	q => 'cmbnq',

	d => 'dlhxzy',
	l => 'dlhxzy',
	h => 'dlhxzy',
	x => 'dlhxzy',
	z => 'dlhxzy',
	y => 'dlhxzy',

	p => 'pieuj',
	i => 'pieuj',
	e => 'pieuj',
	u => 'pieuj',
	j => 'pieuj',

	s => 'sftwo',
	f => 'sftwo',
	t => 'sftwo',
	w => 'sftwo',
	o => 'sftwo',

	0 => 'number',
	1 => 'number',
	2 => 'number',
	3 => 'number',
	4 => 'number',
	5 => 'number',
	6 => 'number',
	7 => 'number',
	8 => 'number',
	9 => 'number',
);

# flag showing if the index is rebuilding or searching
my $rebuilding = 0;

# don't need it because keys are recoreded in db-info
#sub GetDataKey {
#	my @allkey = ();
#	foreach (@dbname) {
#		tie %db, "DBM::Deep", $bindb{$_};
#		push @allkey, (keys %db);
#	}
#	@allkey;
#}

sub GetDataBase {
	my $key_word = shift;

	$key_word =~ /^(.)/;
	my $first = $1;

	my $ret;
	unless (defined($redirect{$first})) {
		$ret = 'fallback';
	} else {
		$ret = $redirect{$first};
	}

	$ret;
}

sub GetDataBaseAll {@dbname}

sub GetDataBaseKind {
	my $key_word = shift;

	$key_word =~ /^(.)/;
	my $first = $1;

	my @ret = ();
	unless (defined($redirect{$first})) {
		push @ret, 'fallback';
	} elsif ($first =~ /[0-9]/) {
		push @ret, 'number';
	} elsif ($first =~ /[a-z]/i) {
		push @ret, qw (sftwo garvk cmbnq pieuj dlhxzy);
	} else {
		@ret = @dbname;
	}

	@ret;
}

sub LoadData {
	my $err = 0;
	foreach  (@dbname) {
		$err++ unless (-e $md5file{$_});
	}

	unless ($err) {
    	ReadData();
    } else {
		InitData();
    }

    1;
}

sub InitData {
    print STDOUT "Initializing index database...\n";

    # clear all the data if exists
    ClearData();

    # store to create "must be existed" files
	StoreData();

	#  the temp files are also needed to be created
	my %tmp = ();
	foreach (@dbname) {
		tie %tmp, "DBM::Deep", $tmpdb{$_};
	}
	untie %tmp;

	# clear the keys recorded in db-info
	$info{ALLKEY} = ();

    # return 1 if all success
    print STDOUT "Initializing done!\n";

	1;
}

sub ReadData {
    print STDOUT "Reading index database...\n";

	foreach my $db_name (@dbname) {
		die "ERROR: Lack of md5 checksum file\n" unless -e $md5file{$db_name};

		tie %db, "DBM::Deep", $bindb{$db_name};

		# check md5 sum
		my $md5new = md5_base64( keys %db );
		open my $md5fh, '<', $md5file{$db_name};

		my $md5old = '';
		while(<$md5fh>) { $md5old = $_; };
		close $md5fh;

		unless ($md5new eq $md5old) {
			print STDOUT "Error in binary database, recovering from text...\n";

			# clear dbm hash
			ClearHash(1);

			# if text database exists, recover from it, or just clear all the data
			if (-e $txtdb{$db_name}) {
				my $data = do {
					if(open my $txtfh, '<', $txtdb{$db_name}) {local $/; <$txtfh>}
					else { undef }
				};
				eval $data;
			} else {
				print STDOUT "Error in text database, clearing all...\n";

				# all index database unreliable, clear all
				ClearData();
			}
		}
	}

	print STDOUT "Reading done!\n";

	1;
}

sub StoreData {
	print STDOUT "Storing index database...\n";

	# check if it is necessary to store all data	
	my $no_need_save = 0;
	my %need_save_db = ();
	foreach my $db_name (@dbname) {
		tie %db, "DBM::Deep", $bindb{$db_name};

		# record the md5 checksum
		my $md5sum = md5_base64( keys %db );

		if (-e $md5file{$db_name}){
			open my $md5fh, '<', $md5file{$db_name};
			my $oldmd5 = '';
			while (<$md5fh>) { $oldmd5 = $_; }
			close $md5fh;

			# most of the time, there is no need to save database
			if ($oldmd5 eq $md5sum) {
				$no_need_save++ ;
			} else {
				$need_save_db{$db_name} = $md5sum;
			}
		} else {
			$need_save_db{$db_name} = $md5sum;
		}
	}

	# IMPROTANT!!! if all the databases don't need to save
	# then will skip  updating md5file and text database
	if($no_need_save == scalar(@dbname)) {
		print STDOUT "No Changes need to be saved!\n";

		# delete all temp database
		foreach my $db_name (@dbname) {
			if ((-e $tmpdb{$db_name})) {
				# The warn may appear on windows os
				unlink $tmpdb{$db_name} or
				  warn "WARN: Cannot delete temp database!";
			}
		}
		# and return immediately
		return 1;
	}

	foreach my $db_name (keys %need_save_db) {
		tie %db, "DBM::Deep", $bindb{$db_name};

		# rewrite md5checksum file
		open my $md5fh, '>', $md5file{$db_name};
		print $md5fh $need_save_db{$db_name};
		close $md5fh;

		# save as txt file
		my $dd = Data::Dumper->new(
			[ \%db ],
			[ qw(*db) ],
		);

		# file handle (write only)
		open my $fh, '>', $txtdb{$db_name};
		print $fh $dd->Dump;
		close $fh;

		# delete temp database if exists
		if ((-e $tmpdb{$db_name}) && !$rebuilding) {
			# God bless me that it won't appear on windows
			unlink $tmpdb{$db_name} or
			  warn "WARN: Cannot delete temp database!";
		}
	}

	print STDOUT "Storing done! ";

	1;
}

sub ClearHash {
	# input argument shows it will clear bindb or tmpdb
	if (shift) {
		foreach my $db_name (@dbname) {
			tie %db, "DBM::Deep", $bindb{$db_name};
			foreach my $var (keys %db) { delete $db{$var}; }
		}
	} else {
		foreach my $db_name (@dbname) {
			tie %db, "DBM::Deep", $tmpdb{$db_name};
			foreach my $var (keys %db) { delete $db{$var}; }
		}
	}
}

sub ClearData {
	# this will clear binary database
	ClearHash(1);

	foreach my $db_name (@dbname) {
		# and delete text database
		unlink $txtdb{$db_name} if -e $txtdb{$db_name};
		# as well as md5 checksum file
		unlink $md5file{$db_name} if -e $md5file{$db_name};
	}
	1;
}

sub BuildData {
	my $target_dir = shift;
	my $not_index = shift;
	if ($not_index) {
		$not_index = join('|', split(/[,\s]+/, $not_index));
	} else {
		$not_index = 0;
	}

	print STDOUT "Building database...\n";

	# only clear hash, leave text database for backup
	ClearHash(1);

	# foreach every dir and scan files
	ForeachDir($target_dir, $not_index);

	# take a record of the target directory
	$info{ROOTDIR} = $target_dir;
	# record the complete time into db-info
	$info{MODTIME} = time();

	print STDOUT "Building done!\n";

	1;
}

sub RebuildData {
	# enter in rebuilding mode
	my $target_path = shift;
	my $not_index = shift;

	$rebuilding = 1;
	print STDOUT "Rebuilding database...\n";

    # on windows just clear and build (permission denied)
    if ($^O =~ /win/i) {
        $rebuilding = 0;
        ClearHash(1);
        BuildData($target_path, $not_index);
        return 1;
    }

	# create new database
	if ( InitData() and BuildData($target_path, $not_index) ) {
		print STDOUT "Rebuilding success...\n";
		# rebuild database success

		# untie first to release grab in windows
		untie %db;

		foreach my $db_name (@dbname) {
			unlink $bindb{$db_name} if -e $bindb{$db_name};
			rename($tmpdb{$db_name}, $bindb{$db_name}) or die $!;
		}
#		tie %db, 'DBM::Deep', $bindb or die $!;
#		tie %tdb, 'DBM::Deep', $tmpdb or die $!;
	} else {
		print STDOUT "Rebuilding error, keep old database.\n";
		ClearHash(0);
	}

	# store the new fresh index data
	print STDOUT "Storing new index data...\n";
	StoreData();

	print STDOUT "Rebuilding done!\n";
	$rebuilding = 0;

	1;
}

sub AddData {
	# check for arguments, must be two
	my $file = shift @_;
	my $path = shift @_;
	if ($file eq '' or $path eq '') {
		die "ERROR: File info misses for adding index data\n";
	}

    # delete extend file name
    $file =~ s/\.[a-zA-Z0-9]+\s*$//i;

	# split name into key words using Split Module
	my @names = Split::NameSplit($file);
	# each name is unique to others

	# now add data by key words
	foreach my $key (sort @names) {
		my @number = ($path =~ m/$key/ig);

		# get the right database
		my $db_name = GetDataBase($key);

		# tie the directed database
		unless ($rebuilding) {
			tie %db, "DBM::Deep", $bindb{$db_name};
		} else {
			tie %db, "DBM::Deep", $tmpdb{$db_name};
		}

		# IMPORTANT!! use the value of info hash key ALLKEY
		# as an array reference to store all the keys for suggestion
		push @{$info{ALLKEY}}, $key unless defined($db{$key});
		# do not push every time, only when it is not defined as a new key

		# insert to hash of hash structure
		$db{$key}->{$path} = $#number + 1;

		# don't need to untie here
#		untie %db;
	}

    # IMPORTANT! update totalnum
    $info{TOTALNUM} += scalar(@names);

	1;
}

sub ForeachDir {
	my $dir = shift;
	my $not_index = shift;

	opendir(DIR, $dir) or warn "WARN: Can't open directory: $dir\n";
	my @allfiles = readdir(DIR);
	closedir(DIR);

	foreach my $file (sort @allfiles) {
		next if ($file eq '.' or $file eq '..');

		# not index this
		next if $not_index and $file =~ /$not_index/i;
#warn "##$file##$not_index\n";

		my $path = catpath(undef, $dir, $file);

		if (-d $path) {

			# IMPORTANT!! skip the links
			next if (-l "$path");
warn "$path\n";
			# recursive searching path
			ForeachDir($path, $not_index);

		} elsif ( ZipCheck($file) ) {
			# get files' names in zip file
			my %zip_file = ZipScan($path);

			foreach my $zip_name (keys %zip_file) {
				next if $not_index and $zip_name =~ /$not_index/i;

				# regard zip file as a directory and add data to database
				AddData($zip_name, $zip_file{$zip_name});
				# ignoring error from the zip
			}
		}

		# split file name first, then add key words to database
		AddData($file, $path);
#warn "$path\n";

	}

    # IMPORTANT! record totalnum as a special key
#	print $dbinfo "$totalnum";
#	$
#	unless ($rebuilding) { $db{__TOTALNUM} = $totalnum }
#	else { $tdb{__TOTALNUM} = $totalnum }

	1;
}

sub ZipScan {
	my ($zipfile) = @_;
	my $zip = Archive::Zip->new();
	my $status = $zip->read($zipfile);
	warn "WARN: Error in zip file $zipfile!\n" if $status != AZ_OK;

	# get all the members' names in zip file
	my @allmembers = $zip->memberNames();
	my %memberhash = ();

	foreach my $member (sort @allmembers) {
		# split dir/file and cat dir with zip file path
		my ($volume, $directory, $file) = File::Spec->splitpath($member);

		# not cool still -_-||
		unless ($file) {
			$directory =~ s/(.*)[\/\\]$//;
			$file = $1;
		}

		$memberhash{$file} = catpath(undef, $zipfile, catpath($directory, $file));
	}

	# return members' info in zip file
	%memberhash;
}

sub ZipCheck {
	my ($zipfile) = @_;
	my $ret = 0;

	# check for zip file
#	if ($^O =~ /win/i) {
		# On Windows and other OS
		# file type is judged by extern name
#		$ret = 1 if $zipfile =~ /\.zip\s*$/;
#	} else {
		# On Linux/Unix/Mac(darwin)
		# file type has nothing to do with extern name
#		$ret = 1 if `file "$zipfile"` =~ /zip/;
		# the "" besides $zipfile is a must!!!
#	}
	$ret = 1 if $zipfile =~ /\.zip\s*$/i;

	# return 1 if it is a zip file
	$ret;
}

1;
