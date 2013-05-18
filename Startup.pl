#!/usr/bin/perl
use warnings;
use strict;
use DBM::Deep;
use Tcl::Tk;
use File::Spec;
use POSIX qw (strftime);
use Encode qw (encode decode);
use Encode::Detect::Detector;

my $int = new Tcl::Tk;
my $mw = $int->mainwindow;

chdir 'src';

tie my %dbinfo, 'DBM::Deep', 'db-info';
my @themes;
foreach (<*>) {
	if (-d $_  and /^(.*)-shell$/) {
		push @themes, $1;
	}
}

# choose the encoding
my $charset = Encode::Detect::Detector::detect($dbinfo{ROOTDIR});
unless ($charset) {
	$charset = "utf-8";
} elsif ($charset =~ /^gb/i) {
	$charset = "GBK";
}

$int->Eval(<<'START');
panedwindow .pw -orient vertical

### here is basic ###
frame .basic

# the first line is title
button .basic.title -text "Ready?" -pady 10 \
	-font {-family sans -size 14 -weight bold -slant italic}

# the second line is other configure
labelframe .basic.cfg -text ""

# cfg about dir
labelframe .basic.cfg.dir -text "Default Index Directory" -font {-size 12} -fg blue
frame .basic.cfg.dir.lbl
label .basic.cfg.dir.lbl.dir -text "Index Directory:" -fg blue
label .basic.cfg.dir.lbl.file -text "File Modify Time :" -fg blue
label .basic.cfg.dir.lbl.content -text "Content Modify Time :" -fg blue
pack .basic.cfg.dir.lbl.dir \
         .basic.cfg.dir.lbl.file \
         .basic.cfg.dir.lbl.content \
         -in .basic.cfg.dir.lbl -side top -anchor nw

frame .basic.cfg.dir.info
label .basic.cfg.dir.info.dir
label .basic.cfg.dir.info.file
label .basic.cfg.dir.info.content
pack .basic.cfg.dir.info.dir \
         .basic.cfg.dir.info.file \
         .basic.cfg.dir.info.content \
         -in .basic.cfg.dir.info -side top -anchor nw

frame .basic.cfg.dir.updatebtn
button .basic.cfg.dir.updatebtn.all -text "Update All" -pady 0 -width 10
button .basic.cfg.dir.updatebtn.file -text "Update File" -pady 0 -width 10
button .basic.cfg.dir.updatebtn.content -text "Update Content" -pady 0 -width 10
pack .basic.cfg.dir.updatebtn.all \
         .basic.cfg.dir.updatebtn.file \
         .basic.cfg.dir.updatebtn.content \
         -in .basic.cfg.dir.updatebtn -side top -anchor nw

pack .basic.cfg.dir.lbl \
         .basic.cfg.dir.info \
         .basic.cfg.dir.updatebtn \
         -in .basic.cfg.dir -side left -anchor nw -padx 5

# cfg about theme
frame .basic.cfg.theme
label .basic.cfg.theme.lbl -text "Theme "
ttk::combobox .basic.cfg.theme.select -state readonly -textvariable cur_theme
pack .basic.cfg.theme.lbl \
         .basic.cfg.theme.select \
         -side left -pady 10

pack .basic.cfg.dir .basic.cfg.theme 

# the third line is more enable button
set more_state 0
button .basic.enablebtn -text "More..." -pady 0 -padx 50 \
	-command {
		if {$more_state} {
			.pw paneconfigure .more -hide true
			.basic.enablebtn configure -text "More..."
		} else {
			.pw paneconfigure .more -hide false
			.basic.enablebtn configure -text "Less..."
		}
		# change state
		set more_state [expr 1-$more_state]
	}

pack .basic.title .basic.cfg .basic.enablebtn -fill both -expand true
### end of basic ###

### here is more ###
frame .more

labelframe .more.rootdir -text "Choose New Directory" -font {-size 12} -fg blue
entry .more.rootdir.dir -width 60 -textvariable newdir

frame .more.rootdir.option
label .more.rootdir.option.lbl1 -text "I don't wanna"
entry .more.rootdir.option.enter -width 30
label .more.rootdir.option.lbl2 -text "to be indexed"
pack .more.rootdir.option.lbl1 \
         .more.rootdir.option.enter \
         .more.rootdir.option.lbl2 \
         -in .more.rootdir.option -side left

pack .more.rootdir.dir .more.rootdir.option -in .more.rootdir -anchor nw

frame .more.btn
button .more.btn.choose -text "Choose" -pady 2 \
	-command {
		set choosed_dir  [tk_chooseDirectory]
		if {"" ne $choosed_dir} {
            set newdir $choosed_dir
		}
}
button .more.btn.rebuild -text "Rebuild" -pady 2
pack .more.btn.choose .more.btn.rebuild -in .more.btn -pady 5


pack .more.rootdir .more.btn -side left -fill both -expand true

### end of more ###

.pw add .basic .more
.pw paneconfigure .more -hide true
pack .pw

wm title . "Start Up"

START

my $infodir = $int->widget('.basic.cfg.dir.info.dir', 'label');
$infodir->configure(-text => $dbinfo{ROOTDIR});

my $infofile = $int->widget('.basic.cfg.dir.info.file', 'label');
$infofile->configure(-text =>
					   strftime "%Y-%m-%d %H:%M:%S", 
					 (localtime $dbinfo{MODTIME})[0..5]);

my $infocontent = $int->widget('.basic.cfg.dir.info.content', 'label');
$infocontent->configure(-text => 
						  strftime "%Y-%m-%d %H:%M:%S", 
						(localtime $dbinfo{CONTENT})[0..5]);

my $cur_theme;
my $theme_choose = $int->
  widget('.basic.cfg.theme.select', 'combobox');
$theme_choose->configure(
	-values => "@themes",
	-textvariable => \$cur_theme,
);
$theme_choose->set("$themes[$#themes]");

my $start_title = $int->widget('.basic.title', 'button');
$start_title->configure(
	-command => sub {
		$cur_theme = Tcl2Shell("$cur_theme-shell");
		exec "perl search-shell.pl $cur_theme";
	}
);

$start_title->bind('<Enter>', sub{$start_title->configure(-text=>"Go!!")});
$start_title->bind('<Leave>', sub{$start_title->configure(-text=>"Ready?")});

$int->widget('.basic.cfg.dir.updatebtn.all', 'button')->configure(
	-command => sub{
		$start_title->configure(-text=>"Updating All Index...");
		$int->update();
		my $index_dir = Tcl2Shell($dbinfo{ROOTDIR});
		`perl rebuild-index.pl "$index_dir" ALL`;

		$infofile->configure(-text =>
							   strftime "%Y-%m-%d %H:%M:%S", 
							 (localtime time())[0..5]);

		$infocontent->configure(-text => 
								  strftime "%Y-%m-%d %H:%M:%S", 
								(localtime time())[0..5]);

		$start_title->configure(-text=>"Ready?");
	}
);

$int->widget('.basic.cfg.dir.updatebtn.file', 'button')->configure(
	-command => sub{
		$start_title->configure(-text=>"Updating File Index...");
		$int->update();
		my $index_dir = Tcl2Shell($dbinfo{ROOTDIR});
		`perl rebuild-index.pl "$index_dir" FILE`;

		$infofile->configure(-text =>
							   strftime "%Y-%m-%d %H:%M:%S",
							 (localtime time())[0..5]);

		$start_title->configure(-text=>"Ready?");
	}
);

$int->widget('.basic.cfg.dir.updatebtn.content', 'button')->configure(
	-command => sub{
		$start_title->configure(-text=>"Updating Content Index...");
		$int->update();
		my $index_dir = Tcl2Shell($dbinfo{ROOTDIR});
		`perl rebuild-index.pl "$index_dir" CONTENT`;

		$infocontent->configure(-text => 
								  strftime "%Y-%m-%d %H:%M:%S", 
								(localtime time())[0..5]);

		$start_title->configure(-text=>"Ready?");
	}
);

$int->widget('.more.btn.rebuild', 'button')->configure(
	-command => sub{
		my $new_dir = $int->widget('.more.rootdir.dir', 'entry')->get();
		my $not_index = $int->widget('.more.rootdir.option.enter', 'entry')->get();

		$start_title->configure(-text=>"Rebuilding New Index...");
		$int->update();

		my $index_dir = Tcl2Shell("$new_dir");
		$not_index = Tcl2Shell("$not_index");
		`perl rebuild-index.pl "$index_dir" ALL "$not_index"`;

		$infodir->configure(-text => $new_dir);
		$infofile->configure(-text =>
							   strftime "%Y-%m-%d %H:%M:%S", 
							 (localtime time())[0..5]);
		$infocontent->configure(-text => 
								  strftime "%Y-%m-%d %H:%M:%S", 
								(localtime time())[0..5]);


		$start_title->configure(-text=>"Ready?");
	}
);


# start interpreterS
$int->MainLoop;

sub Tcl2Shell { encode("$charset", decode('unicode', shift)) }

