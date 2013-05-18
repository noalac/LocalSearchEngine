#!/usr/bin/perl

use warnings;
use strict;
use Tcl::Tk;
use Index;
use Search;
use Kino;
use Net;
use AudioFile::Info;
use MP4::Info;
use CAM::PDF;
use File::Spec;
use Data::Dumper qw(Dumper);
use Encode qw(encode decode);
use Encode::Detect::Detector;
use Net::Ping::External qw(ping);
use POSIX qw(strftime);
use Archive::Zip qw(:ERROR_CODES :CONSTANTS);
use DBM::Deep;

BEGIN { Index::LoadData() };

#my $rootdir = $ARGV[0];
#my $theme = $ARGV[1];

# tie db-info to use the TOTALNUM
tie my %dbinfo, "DBM::Deep", "db-info";

my $rootdir = $dbinfo{ROOTDIR};
my $charset = Encode::Detect::Detector::detect($rootdir);
unless ($charset) {
	# set default by platforms
    if ($^O =~ /win/i) {
    	$charset = "GBK";
    } else {
    	$charset = "utf-8";
    }
} elsif ($charset =~ /^gb/i) {
	# GBK is bigger than gb2312
	$charset = "GBK";
}

my $theme;
if ($ARGV[0] and (-e $ARGV[0])) {
	$theme = $ARGV[0];
} else {
	# default theme
	$theme = "iPhone-shell";
}

my $show_root_dir = Perl2Tcl($rootdir);
# limit the max show length as 40 characters
$show_root_dir =~ s/^(.{37}).*$/$1.../ if 40 < length($show_root_dir);

my $int = new Tcl::Tk;
my $mw = $int->mainwindow;

$int->Eval(<<'LOAD');
# load Img package to read PNG/BMP/....
if {[catch {package require Img}]} {
   puts stderr "Cannot load Img package for Tcl"
}

# enable animation gif
lappend auto_path .
package require anigif 1.3
LOAD

chdir $theme;

$int->Eval(<<'EOS');
##################### GLOBAL VARIABLE #####################

# window title
set wmtitle "Search Shell"

# cursor start position
set curx 0
set cury 0

##################### END OF GLOBAL #####################

# load in theme config
source config.tcl

##################### VERTICAL WINDOW #####################
toplevel .vertical

# background image
image create photo ::img::bgv \
    -format GIF -file shell_vertical.gif
canvas .vertical.shell -width $bgwidth -height $bgheight
.vertical.shell create image \
    [expr $bgwidth / 2] [expr $bgheight / 2] \
    -image ::img::bgv
pack .vertical.shell -anchor nw

# start up displaying button
image create photo ::img::start \
    -format GIF -file startup.gif
button .vertical.start -image ::img::start \
    -state disabled \
    -command { destroy .vertical.start }
place .vertical.start -x $startx -y $starty
label .vertical.start.stat -text "Loading..." \
    -textvariable startload
place .vertical.start.stat -x 0 -y 0


# for turning animation
label .vertical.turning -width $bgwidth -height $bgheight
place .vertical.turning -anchor nw
lower .vertical.turning
# for turning back
label .vertical.turnback -width $bgwidth -height $bgheight
place .vertical.turnback -anchor nw
lower .vertical.turnback

# back of the shell
image create photo ::img::bgb \
    -format GIF -file shell_back.gif
canvas .vertical.back -width $bgwidth -height $bgheight
.vertical.back create image \
    [expr $bgwidth / 2] [expr $bgheight /2] \
    -image ::img::bgb
label .vertical.back.info -text $backtext -width 8 \
    -bg $backbgcolor -fg $backfgcolor \
    -font {-family Arial -size 18 -weight bold}
place .vertical.back.info -x $backx -y $backy
place .vertical.back -anchor nw
lower .vertical.back

# This is help info stardard window
bind .vertical.back.info <1> {
    tk_messageBox -type ok -icon info -title "Help & Version" \
    -parent .vertical.back \
    -message $helpmessage
}

# rotate button
image create photo ::img::rot2h \
    -format GIF -file rotate2h.gif
button .vertical.shell.rot2h -image ::img::rot2h -borderwidth 0 \
    -command {
        wm state .horizontal normal
        wm state .vertical withdraw
    }
place .vertical.shell.rot2h -x $vrotbtnx -y $vrotbtny

# search button
button .vertical.shell.sbtn -bg #$sbtncolor \
    -text $sbtntext -foreground white \
    -font {-family helvetica -size 9 -weight bold} \
    -borderwidth 3 -relief groove -pady 2 -padx 2
place .vertical.shell.sbtn -x $vsbtnx -y $vsbtny

# clear button
image create photo ::img::clear \
    -format GIF -file clear.gif
button .vertical.shell.clear -image ::img::clear \
    -borderwidth 0
place .vertical.shell.clear -x $vclrbtnx -y $vclrbtny

# enter string for searching
entry .vertical.shell.enter \
    -font {-family time -size 10 -weight bold} \
    -insertwidth 4 -relief sunken -textvariable text
bind .vertical.shell.enter <Return> {
    .vertical.shell.sbtn flash
    .vertical.shell.sbtn invoke
}
place .vertical.shell.enter -x $ventx -y $venty -width $ventwidth

# give suggestion when typing keywords
listbox .vertical.suggest -font {-family time -size 10 -weight bold}
place .vertical.suggest -x $vsuggestx -y $vsuggesty \
    -width $ventwidth -height $vsuggestheight
lower .vertical.suggest

# status label
label .vertical.shell.status -bg black -foreground white \
    -font {-family impact -size 10}
place .vertical.shell.status -x $vstatlblx -y $vstatlbly

# option background
image create photo ::img::optbg \
    -format GIF -file option_bg.gif

# option 1
canvas .vertical.shell.opt1 -width $optwidth -height $optheight
.vertical.shell.opt1 create image \
    [expr $optwidth / 2] [expr $optheight / 2] \
    -image ::img::optbg
place .vertical.shell.opt1 -x $vopt1x -y $vopt1y

# option 2
canvas .vertical.shell.opt2 -width $optwidth -height $optheight
.vertical.shell.opt2 create image \
    [expr $optwidth / 2] [expr $optheight / 2] \
    -image ::img::optbg
place .vertical.shell.opt2 -x $vopt2x -y $vopt2y

# option 3
canvas .vertical.shell.opt3 -width $optwidth -height $optheight
.vertical.shell.opt3 create image \
    [expr $optwidth / 2] [expr $optheight / 2] \
    -image ::img::optbg
place .vertical.shell.opt3 -x $vopt3x -y $vopt3y

# make sure that total step is less than 15
if {[expr $totalstep > 15]} {set totalstep 15}
# make sure that total step is more than 1
if {[expr $totalstep < 1]} {set totalstep 1}

# start creating rectangles
set i 1
set curcolor1 ""
while {[expr $i <= $totalstep]} {
    set curtag "t$i"
    set curcolor1 "#"
    append curcolor1 [format %x $i] "$g$b"
    .vertical.shell.opt1 create rectangle \
        [expr $x0 + $i * $x0incr] $y0 \
        [expr $xt + $i * $xtincr] $yt \
        -fill "$curcolor1" -tags "$curtag"

    .vertical.shell.opt1 lower $curtag
    incr i
}
set i 1
set curcolor2 ""
while {[expr $i <= $totalstep]} {
    set curtag "t$i"
    set curcolor2 "#"
    append curcolor2 "$r" [format %x $i] "$b"
    .vertical.shell.opt2 create rectangle \
        [expr $x0 + $i * $x0incr] $y0 \
        [expr $xt + $i * $xtincr] $yt \
        -fill "$curcolor2" -tags "$curtag"

    .vertical.shell.opt2 lower $curtag
    incr i
}
set i 1
set curcolor3 ""
while {[expr $i <= $totalstep]} {
    set curtag "t$i"
    set curcolor3 "#"
    append curcolor3 "$r$g" [format %x $i]
    .vertical.shell.opt3 create rectangle \
        [expr $x0 + $i * $x0incr] $y0 \
        [expr $xt + $i * $xtincr] $yt \
        -fill "$curcolor3" -tags "$curtag"

    .vertical.shell.opt3 lower $curtag
    incr i
}

# opt1 include all
entry .vertical.shell.includeall -width $vincludewidth
place .vertical.shell.includeall -x $vinallx -y $vinally
lower .vertical.shell.includeall
label .vertical.shell.includealllbl -text "Include ALL" \
    -bg $curcolor1 -font {-family sans -size 10 -weight bold}
place .vertical.shell.includealllbl -x $vincludelbl -y $vinally
lower .vertical.shell.includealllbl

# opt2 include not
entry .vertical.shell.includenot -width $vincludewidth
place .vertical.shell.includenot -x $vinnotx -y $vinnoty
lower .vertical.shell.includenot
label .vertical.shell.includenotlbl -text "Include NOT" \
    -bg $curcolor2 -font {-family sans -size 10 -weight bold}
place .vertical.shell.includenotlbl -x $vincludelbl -y $vinnoty
lower .vertical.shell.includenotlbl

# opt3 case sensitive
checkbutton .vertical.shell.casesen -text "Case Sensitive" \
    -bg $curcolor3 -font {-family sans -size 10 -weight bold} \
    -onvalue 1 -offvalue 0 -variable casesen
place .vertical.shell.casesen -x $vcasex -y $vcasey
lower .vertical.shell.casesen
set is_casesen 0

# opt4 content search
checkbutton .vertical.shell.content -text "Be Strict" \
    -bg $curcolor3 -font {-family sans -size 10 -weight bold} \
    -onvalue 1 -offvalue 0 -variable content
place .vertical.shell.content -x $vcontx -y $vconty
lower .vertical.shell.content
set is_content 0



# show results top frame
frame .vertical.result
place .vertical.result -x $vrstshowx -y $vrstshowy

# result show frame
frame .vertical.result.rstshow
listbox .vertical.result.rstshow.lbox -width $vlboxwidth -height $vlboxheight \
    -yscrollcommand ".vertical.result.rstshow.scroll set" \
    -font {-family $vrstfont -size 12}
scrollbar .vertical.result.rstshow.scroll \
    -command ".vertical.result.rstshow.lbox yview"
grid .vertical.result.rstshow.lbox -in .vertical.result.rstshow \
    -row 0 -column 0 -sticky nsew
grid .vertical.result.rstshow.scroll -in .vertical.result.rstshow \
    -row 0 -column 1 -sticky ns
grid rowconfigure .vertical.result.rstshow 0 -weight 1
grid columnconfigure .vertical.result.rstshow 0 -weight 1

# result option frame
frame .vertical.result.rstoption
spinbox .vertical.result.rstoption.spin  -values {ALL DIRE FILE TEXT BIN} \
    -width 10
ttk::scale .vertical.result.rstoption.scale -from 0 -to 1 -orient horizontal \
    -variable scale -length 16m
label .vertical.result.rstoption.label1 -text "Filter"
label .vertical.result.rstoption.label2 -text "  File/Content"
button .vertical.result.rstoption.cancelbtn -text "X" -width 0 -height 0 \
    -pady 0 -padx 4 \
    -command {
        lower .horizontal.result
        lower .vertical.result
        set locked 0
    }
pack .vertical.result.rstoption.label1 \
     .vertical.result.rstoption.spin \
     .vertical.result.rstoption.label2 \
     .vertical.result.rstoption.scale \
     .vertical.result.rstoption.cancelbtn \
     -in .vertical.result.rstoption \
     -side left

# pack two frame together into result top canvas
pack .vertical.result.rstshow .vertical.result.rstoption -in .vertical.result -side top
lower .vertical.result.rstshow
lower .vertical.result.rstoption
lower .vertical.result

##################### END OF VERTICAL #####################


##################### HORIzONTAL WINDOW ####################
toplevel .horizontal

image create photo ::img::bgh \
    -format GIF -file shell_horizontal.gif
canvas .horizontal.shell -width $hbgwidth -height $hbgheight
.horizontal.shell create image \
    [expr $hbgwidth / 2] [expr $hbgheight / 2] \
    -image ::img::bgh
pack .horizontal.shell

# rotate button
image create photo ::img::rot2v -format GIF -file rotate2v.gif
button .horizontal.shell.rot2v -image ::img::rot2v -borderwidth 0 \
    -command {
        wm state .vertical normal
        wm state .horizontal withdraw
    }
place .horizontal.shell.rot2v -x $hrotbtnx -y $hrotbtny

# clear button
button .horizontal.shell.clear -image ::img::clear \
    -borderwidth 0
place .horizontal.shell.clear -x $hclrbtnx -y $hclrbtny

# search button
button .horizontal.shell.sbtn -bg #$sbtncolor \
    -text $sbtntext -foreground white \
    -font {-family helvetica -size 12 -weight bold} \
    -borderwidth 3 -relief groove -pady 2 -padx 2
place .horizontal.shell.sbtn -x $hsbtnx -y $hsbtny

# enter string for searching
entry .horizontal.shell.enter \
    -font {-family time -size 13 -weight bold} \
    -insertwidth 4 -relief sunken -textvariable text
bind .horizontal.shell.enter <Return> {
    .horizontal.shell.sbtn flash
    .horizontal.shell.sbtn invoke
}
place .horizontal.shell.enter -x $hentx -y $henty -width $hentwidth

# give suggestion when typing keywords
listbox .horizontal.suggest  -font {-family time -size 13 -weight bold}
place .horizontal.suggest -x $hsuggestx -y $hsuggesty \
    -width $hentwidth -height $hsuggestheight
lower .horizontal.suggest

# status label
label .horizontal.shell.status -bg black -foreground white \
    -font {-family impact -size 10}
place .horizontal.shell.status -x $hstatlblx -y $hstatlbly

# show results top frame
frame .horizontal.result
place .horizontal.result -x $hrstshowx -y $hrstshowy

# result show frame
frame .horizontal.result.rstshow
listbox .horizontal.result.rstshow.lbox -width $hlboxwidth -height $hlboxheight \
    -yscrollcommand ".horizontal.result.rstshow.scroll set" \
    -font {-family $hrstfont -size 13}
scrollbar .horizontal.result.rstshow.scroll \
    -command ".horizontal.result.rstshow.lbox yview"
grid .horizontal.result.rstshow.lbox -in .horizontal.result.rstshow \
    -row 0 -column 0 -sticky nsew
grid .horizontal.result.rstshow.scroll -in .horizontal.result.rstshow \
    -row 0 -column 1 -sticky ns
grid rowconfigure .horizontal.result.rstshow 0 -weight 1
grid columnconfigure .horizontal.result.rstshow 0 -weight 1

# result option frame
frame .horizontal.result.rstoption
spinbox .horizontal.result.rstoption.spin  -values {ALL DIRE FILE TEXT BIN} \
    -width 20
ttk::scale .horizontal.result.rstoption.scale -from 0 -to 1 -orient horizontal \
    -variable scale -length 16m
label .horizontal.result.rstoption.label1 -text "Filter"
label .horizontal.result.rstoption.label2 -text "  File/Content"
button .horizontal.result.rstoption.cancelbtn -text "X" -width 0 -height 0 \
    -pady 0 -padx 4 \
    -command {
        lower .horizontal.result
        lower .vertical.result
        set locked 0
    }
pack .horizontal.result.rstoption.label1 \
     .horizontal.result.rstoption.spin \
     .horizontal.result.rstoption.label2 \
     .horizontal.result.rstoption.scale \
     .horizontal.result.rstoption.cancelbtn \
     -in .horizontal.result.rstoption \
     -side left

# pack two frame together into result top frame
pack .horizontal.result.rstshow .horizontal.result.rstoption \
    -in .horizontal.result -side top
lower .horizontal.result.rstshow
lower .horizontal.result.rstoption
lower .horizontal.result

##################### END OF HORIzONTAL #####################

##################### BINDING EVENT #####################

# bind mouse motion with x y
#bind .vertical.shell   <Motion> {puts "at %x, %y"}
#bind .horizontal.shell <Motion> {puts "at %x, %y"}

# bind mouse motion xy to current window
bind .vertical.shell <ButtonPress-1> {
    set curx %x
    set cury %y
}
bind .vertical.back <ButtonPress-1> {
    set curx %x
    set cury %y
}

# slide action
bind .vertical.shell <ButtonRelease-1> {
    set diffx [expr %x - $curx]
    set diffy [expr %y - $cury]

    if {[expr abs($diffy) < 50] && [expr $diffx > 250]} {

        raise .vertical.turning
        ::anigif::restart .vertical.turning
        after $rottime {
            ::anigif::stop .vertical.turning
            lower .vertical.turning
            raise .vertical.back

            # make sure animation really stopped
            after 100 ::anigif::stop .vertical.turning

        }
    }
}
bind .vertical.back <ButtonRelease-1> {
    set diffx [expr $curx - %x]
    set diffy [expr %y - $cury]
    if {[expr abs($diffy) < 50] && [expr $diffx > 250]} {

        raise .vertical.turnback
        ::anigif::restart .vertical.turnback
        after $rottime {
            ::anigif::stop .vertical.turnback
            lower .vertical.turnback
            raise .vertical.shell

            # make sure animation really stopped
            after 100 ::anigif::stop .vertical.turnback
        }
    }
}

# turn checkbuttons to selected or not selected
bind .vertical.shell.casesen <1> {
    set is_casesen [expr 1 - $is_casesen]
}
bind .vertical.shell.content <1> {
    set is_content [expr 1 - $is_content]
}


# when option menu slide in/out
proc slide_in {no step totalstep interval} {
    incr step
    .vertical.shell.opt$no raise "t$step"

    if {[expr $step == $totalstep]} {
        return 1
    } else {
        after $interval slide_in $no $step $totalstep $interval
    }
}
proc slide_out {no step totalstep interval} {
    .vertical.shell.opt$no lower "t$step"
    set step [expr $step - 1]

    if {[expr $step == 0]} {
        return 1
    } else {
        after $interval slide_out $no $step $totalstep $interval
    }
}

# add physical event to virtual event
event add <<ClickSlideIn>> <Enter>
# have to do something more on windows
#if {[regexp -nocase {windows} $tcl_platform(platform)]} {
event add <<ClickSlideIn>> <1>
#}

# start binding
set locked 0
bind .vertical.shell.opt1 <<ClickSlideIn>> {
    if {$locked} { break }
    if {$animorient} {
        set area %x
    } else {
        set area [expr $optwidth - %x]
    }
    if {[expr $area < 30]} {
        slide_in 1 0 $totalstep $interval
        # show
        after [expr $totalstep * $interval] {
            raise .vertical.shell.includeall
            raise .vertical.shell.includealllbl
        }
    }
}
bind .vertical.shell.opt1 <Leave> {
    if {$locked} { break }
    set text [.vertical.shell.includeall get]
    if {[regexp {^\s*$} $text]} {
        if { [expr %x < 0] || [expr %x > $optwidth] || \
             [expr %y < 0] || [expr %y > $optheight] } {

            slide_out 1 $totalstep $totalstep $interval
            # hide
            lower .vertical.shell.includeall
            lower .vertical.shell.includealllbl
        }
    }
}
bind .vertical.shell.opt2 <<ClickSlideIn>> {
    if {$locked} { break }
    if {$animorient} {
        set area %x
    } else {
        set area [expr $optwidth - %x]
    }
    if {[expr $area < 30]} {
        slide_in 2 0 $totalstep $interval
        # show
        after [expr $totalstep * $interval] {
            raise .vertical.shell.includenot
            raise .vertical.shell.includenotlbl
        }
    }
}
bind .vertical.shell.opt2 <Leave> {
    if {$locked} { break }
    set text [.vertical.shell.includenot get]
    if {[regexp {^\s*$} $text]} {
        if { [expr %x < 0] || [expr %x > $optwidth] || \
             [expr %y < 0] || [expr %y > $optheight] } {

            slide_out 2 $totalstep $totalstep $interval
            # hide
            lower .vertical.shell.includenot
            lower .vertical.shell.includenotlbl
        }
    }
}
bind .vertical.shell.opt3 <<ClickSlideIn>> {
    if {$locked} { break }
    if {$animorient} {
        set area %x
    } else {
        set area [expr $optwidth - %x]
    }
    if {[expr $area < 30]} {
        slide_in 3 0 $totalstep $interval
        # show
        after [expr $totalstep * $interval] {
            raise .vertical.shell.casesen
            raise .vertical.shell.content
        }
    }
}
bind .vertical.shell.opt3 <Leave> {
    if {$locked} { break }
    if {!$is_casesen && !$is_content} {
        if { [expr %x < 0] || [expr %x > $optwidth] || \
             [expr %y < 0] || [expr %y > $optheight] } {

            slide_out 3 $totalstep $totalstep $interval
            # hide
            lower .vertical.shell.casesen
            lower .vertical.shell.content
        }
    }
}

# this is for giving suggestion keyboard binding event
set key_list [list a b c d e f g h i g k l m n o p q r s t u v w x y z 0 1 2 3 4 5 6 7 8 9]
foreach {x} $key_list { event add <<KeyBoard>> <KeyRelease-$x> }
event add <<KeyBoard>> <KeyRelease-Delete>
event add <<KeyBoard>> <KeyRelease-BackSpace>
event add <<KeyBoard>> <KeyRelease-space>

##################### END OF BINDING #####################

##################### MORE INFORMATION ###################

set leftwidth 600
set leftheight 550

toplevel .more
panedwindow .more.pw -orient horizontal

# left frame
frame .more.left

# scrolled canvas but it is actually not
canvas .more.left.result -width $leftwidth -height $leftheight \
    -yscrollcommand ".more.left.scroll set" -bg white
scrollbar .more.left.scroll -orient vertical \
    -command ".more.left.result yview"

# grid into left frame
grid .more.left.result -in .more.left -row 0 -column 0 -sticky nsew
grid .more.left.scroll -in .more.left -row 0 -column 1 -sticky ns
grid rowconfigure .more.left 0 -weight 1
grid columnconfigure .more.left 0 -weight 1

# this frame will be implemented afterwards
frame .more.left.result.show -bg white

# this text widget is for preview
text .more.left.result.preview -bg white -wrap word \
    -width 34 -height 1  -borderwidth 0 -state disabled

# pack them together
pack .more.left.result.show .more.left.result.preview \
    -in .more.left.result -side left -anchor center -expand true -fill both

# right frame
frame .more.right

# result filter
labelframe .more.right.filter -text "Result Filter"  -font {-size 12 -weight bold}
entry .more.right.filter.enter -font {-family Verdana -size 10}
pack .more.right.filter.enter -in .more.right.filter -padx 10 -pady 5

# sort result by option
frame .more.right.sort
label .more.right.sort.lbl -text "Sorted By" -font {-size 12 -weight bold}
frame .more.right.sort.choose
button .more.right.sort.choose.up -text Up -pady 0 -padx 15
button .more.right.sort.choose.down -text Down -pady 0 -padx 5
ttk::combobox .more.right.sort.choose.cbox -values {SCORE NAME DATE SIZE} \
   -width 12 -font {-family Verdana -size 10} -textvariable sortvar
pack .more.right.sort.choose.cbox \
         .more.right.sort.choose.up \
       .more.right.sort.choose.down \
         -in .more.right.sort.choose -side left
pack .more.right.sort.lbl .more.right.sort.choose -in .more.right.sort -anchor nw
.more.right.sort.choose.cbox set SCORE
.more.right.sort.choose.down configure -state disabled

frame .more.right.type
label .more.right.type.lbl -text "I Want These Types" -font {-size 12 -weight bold}
frame .more.right.type.frame
checkbutton .more.right.type.frame.audio -text audio -variable isaudio
checkbutton .more.right.type.frame.photo -text photo -variable isphoto
checkbutton .more.right.type.frame.doc -text doc -variable isdoc
checkbutton .more.right.type.frame.folder -text folder -variable isfolder
checkbutton .more.right.type.frame.file -text file -variable isfile
checkbutton .more.right.type.frame.zip -text zip -variable iszip
set isaudio 1
set isphoto 1
set isdoc 1
set isfolder 1
set iszip 1
set isfile 1
grid .more.right.type.frame.audio -in .more.right.type.frame \
    -row 0 -column 0 -sticky nw
grid .more.right.type.frame.photo -in .more.right.type.frame \
    -row 0 -column 1  -sticky nw
grid .more.right.type.frame.doc -in .more.right.type.frame \
    -row 0 -column 2  -sticky nw
grid .more.right.type.frame.folder -in .more.right.type.frame \
    -row 1 -column 0  -sticky nw
grid .more.right.type.frame.zip -in .more.right.type.frame \
    -row 1 -column 1  -sticky nw
grid .more.right.type.frame.file -in .more.right.type.frame \
    -row 1 -column 2  -sticky nw

pack .more.right.type.lbl \
         .more.right.type.frame \
         -in .more.right.type -side top -anchor nw

# network link
frame .more.right.net
label .more.right.net.lbl -text "Search From Internet" -font {-size 12 -weight bold}
frame .more.right.net.btnframe
button .more.right.net.btnframe.baidu -text Baidu -padx 33 -bg #ccf
button .more.right.net.btnframe.yahoo -text Yahoo -padx 33 -bg #fbd
listbox .more.right.net.lbox -font {-family Verdana -size 12 -underline true}

pack .more.right.net.btnframe.baidu \
         .more.right.net.btnframe.yahoo \
         -in .more.right.net.btnframe -side left -padx 0
pack .more.right.net.lbl \
         .more.right.net.btnframe \
         .more.right.net.lbox \
         -in .more.right.net -side top -anchor nw
# insert initial information
.more.right.net.lbox insert 0 "No Information"

# pack into right frame
pack .more.right.filter \
        .more.right.sort \
        .more.right.type \
        .more.right.net \
        -in .more.right -side top -anchor nw -pady 10

# add left and right frames into panedwindow
.more.pw add .more.left .more.right
pack .more.pw

# set sashwidth as zero to disable resizing between panedwindows
.more.pw configure -sashwidth 0

# disable resizing for more information window
wm resizable .more 0 0

if {[regexp -nocase {windows} $tcl_platform(platform)]} {
    wm attribute .more -topmost true
}

wm title .more "More Information"
wm state .more withdraw
wm protocol .more WM_DELETE_WINDOW { wm state .more withdraw }

# add start more info button
image create photo ::img::moreinfo -format GIF -file moreinfo.gif
label .vertical.shell.moreinfo -image ::img::moreinfo -bd 0
place .vertical.shell.moreinfo -x $vmoreinfox -y $vmoreinfoy
label .horizontal.shell.moreinfo -image ::img::moreinfo -bd 0
place .horizontal.shell.moreinfo -x $hmoreinfox -y $hmoreinfoy

#################### END OF MORE ##########################

#################### WINDOW CONFIGURE ####################

# shut down main window, only show toplevel window
wm withdraw .
# close horizontal window at beginning
wm withdraw .horizontal

# shut will shut down all windows
toplevel .exit
wm title .exit "Confirm"
label .exit.info -text "Are you sure to exit?" -font {-family Time -size 12 -weight bold}
button .exit.ok -text OK -width 6
button .exit.cancel -text Cancel -width 6 \
    -command {
        grab release .exit
        wm state .exit withdraw
    }
grid .exit.info -column 1 -columnspan 2 -padx 20 -pady 10
grid .exit.ok -column 1 -row 2 -padx 10 -pady 10
grid .exit.cancel -column 2 -row 2 -padx 10 -pady 10
wm withdraw .exit
if {[regexp -nocase {windows} $tcl_platform(platform)]} {
    wm attribute .exit -topmost true
}
wm geometry .exit =235x92-[expr ($bgwidth-235)/2]-[expr $bgheight/2]
#wm overrideredirect .exit true

proc shut_down {} {
    if {[string equal normal [wm state .vertical]]} {
        set shellpos [wm geometry .vertical]
     } else {
        set shellpos [wm geometry .horizontal]
     }
    set poslist [split $shellpos x+-]
    lassign $poslist pw ph px py

    set newgeo 235x92-[expr $px+($pw-235)/2]-[expr $py+($ph-92)/2]

    wm geometry .exit =$newgeo
    wm state .exit normal
    grab set -global .exit
}
wm protocol .horizontal WM_DELETE_WINDOW { shut_down }
wm protocol .vertical   WM_DELETE_WINDOW { shut_down }

# set window title
wm title .horizontal "$wmtitle (Fuzzy Mode)"
wm title .vertical   "$wmtitle (Specific Mode)"

# set window position
wm geometry .horizontal -0-0
wm geometry .vertical   -0-0

# IMPORTANT LOAD WM ICON HERE MUST
image create photo ::img::wmicon \
    -format GIF -file wm_icon.gif
wm iconphoto .vertical ::img::wmicon
wm iconphoto .horizontal ::img::wmicon

# disable window resize
wm resizable .vertical 0 0
wm resizable .horizontal 0 0

# enable override-redirect window
#wm overrideredirect .horizontal true
#wm overrideredirect .vertical   true

##################### END OF CONFIGURE #####################


##################### ANIMATION GIF #####################
# load animation gif
::anigif::anigif turning.gif .vertical.turning
::anigif::anigif turnback.gif .vertical.turnback

# stop animation at beginning
::anigif::stop .vertical.turning
::anigif::stop .vertical.turnback

##################### END OF ANIMATION #####################

EOS

# icons
my $file_icon = $int->imageCreate('photo', -file => 'file.gif');
my $folder_icon = $int->imageCreate('photo', -file => 'folder.gif');
my $zip_icon = $int->imageCreate('photo', -file => 'zip.gif');
my $audio_icon = $int->imageCreate('photo', -file => 'audio.gif');
my $photo_icon = $int->imageCreate('photo', -file => 'photo.gif');
my $doc_icon = $int->imageCreate('photo', -file => 'doc.gif');

# IMPORTANT! MUST RETURN TO MAIN DIR HERE!!!
chdir File::Spec->updir();
# IMPORTANT! MUST RETURN TO MAIN DIR HERE!!!

my $text = "";
my $status = "Root: $show_root_dir";
my $includeall = "";
my $includenot = "";
my $casesen = 0;
my $content = 0;
my $scale = 0;
my $filter = "ALL";

my %result = ();
my @content_result = ();
my @sorted_file = ();

my @historys = ();

# vertical commands
my $v_ety_enter = $int->widget('.vertical.shell.enter', 'entry');
$v_ety_enter->configure(-textvariable => \$text);

$int->widget('.vertical.shell.status', 'label')->
  configure(-textvariable => \$status);

my $v_btn_search = $int->widget('.vertical.shell.sbtn', 'button');
$v_btn_search->configure(-command => sub{ search_action(1) });

$int->widget('.vertical.shell.clear', 'button')->
  configure(-command => sub{ clear_action(1); });

$int->widget('.vertical.shell.includeall', 'entry')->
  configure(-textvariable => \$includeall);

$int->widget('.vertical.shell.includenot', 'entry')->
  configure(-textvariable => \$includenot);

$int->widget('.vertical.shell.casesen', 'checkbutton')->
  configure(-variable => \$casesen);

my $v_cont_search = $int->widget('.vertical.shell.content', 'checkbutton');
$v_cont_search->configure(-variable => \$content);

my $v_lbox_rst = $int->widget('.vertical.result.rstshow.lbox', 'listbox');
$v_lbox_rst->bind('<Double-Button-1>' =>
    sub{
		my $index = $v_lbox_rst->curselection();
		my $file = $v_lbox_rst->get($index);
		open_file($file, $index);
	}
);

my $v_scal_opt = $int->widget('.vertical.result.rstoption.scale', 'scale');
$v_scal_opt->configure('-variable' => \$scale);
$v_scal_opt->configure(-command =>
    sub {
		if($scale) { show_content() }
		else { show_result() }
	}
);

my $v_filter_opt = $int->widget('.vertical.result.rstoption.spin', 'spinbox');
$v_filter_opt->configure('-textvariable' => \$filter);
$v_filter_opt->configure('-command' => sub { result_filter() });

# horizontal commands
my $h_ety_enter = $int->widget('.horizontal.shell.enter', 'entry');
$h_ety_enter->configure(-textvariable => \$text);

$int->widget('.horizontal.shell.status', 'label')->
  configure(-textvariable => \$status);

my $h_btn_search = $int->widget('.horizontal.shell.sbtn', 'button');
$h_btn_search->configure(-command => sub{ search_action(0) });

$int->widget('.horizontal.shell.clear', 'button')->
  configure(-command => sub{ clear_action(0) });

my $h_lbox_rst = $int->widget('.horizontal.result.rstshow.lbox', 'listbox');
$h_lbox_rst->bind('<Double-Button-1>' =>
    sub {
		my $index = $h_lbox_rst->curselection();
		my $file = $h_lbox_rst->get($index);
		open_file($file, $index);
	}
);

my $h_scal_opt = $int->widget('.horizontal.result.rstoption.scale', 'scale');
$h_scal_opt->configure('-variable' => \$scale);
$h_scal_opt->configure(-command =>
    sub {
		if($scale) { show_content() }
		else { show_result() }
	}
);

my $h_filter_opt = $int->widget('.horizontal.result.rstoption.spin', 'spinbox');
$h_filter_opt->configure('-textvariable' => \$filter);
$h_filter_opt->configure('-command' => sub { result_filter() });

# exit window command
$int->widget('.exit.ok', 'button')->
  configure(-command =>
    sub {
		$int->widget('.exit', 'toplevel')->grabRelease();

		$status = 'Exiting . . .';
		$int->update();
		exit;
	}
);

# back label style button
#$int->widget('.vertical.back.info', 'label')->bind('<1>' =>
 #   sub {
#		1;
#	}
#);

# check for forbidden words
$v_ety_enter->configure(-validate => 'key');
$v_ety_enter->configure(-validatecommand => sub{ check_input() });
$h_ety_enter->configure(-validate => 'key');
$h_ety_enter->configure(-validatecommand => sub{ check_input() });

# give suggestion
my $is_suggesting = 0;
my $last_input_length = 0;
my @suggest_words = @{$dbinfo{ALLKEY}};
my $v_suggest_lbox = $int->widget('.vertical.suggest', 'listbox');
my $h_suggest_lbox = $int->widget('.horizontal.suggest', 'listbox');

$v_suggest_lbox->bind('<Double-Button-1>', 
    sub { 
		my $index = $v_suggest_lbox->curselection();
		my $word = $v_suggest_lbox->get($index);

		complete_suggestion($word);
	}
);
$h_suggest_lbox->bind('<Double-Button-1>',
    sub {
		my $index = $h_suggest_lbox->curselection();
		my $word = $h_suggest_lbox->get($index);

		complete_suggestion($word);
	}
);

sub complete_suggestion {
	my $word = shift;

	# use ungreedy mode to regexp the nearest one
	if ($text =~ /^\s*$/) {
		# complete history
		$text = $word;
	}elsif ($text =~ /^[\s,]*[^\s,]+[\s,]*$/) {
		# the text is at the beginning
		$text =~ s/[^\s,]+/$word/;
	} else {
		# the other situation
		$text =~ s/([\s,])[^\s,]+?$/$1$word/i;
	}

	$v_suggest_lbox->lower();
	$h_suggest_lbox->lower();
	$is_suggesting = 0;

	1;
}

# IMPORTANT!! the binding key event does not include <Return>
$h_ety_enter->bind('<<KeyBoard>>', sub { give_suggestion() });
$v_ety_enter->bind('<<KeyBoard>>', sub { give_suggestion() });

sub give_suggestion {
	# if input is empty, lower the text widget
	if ($text eq "") {
		$v_suggest_lbox->lower();
		$h_suggest_lbox->lower();
		$is_suggesting = 0;
	}

	# clear the suggestion listbox
	$v_suggest_lbox->_delete('0', 'end');
	$h_suggest_lbox->_delete('0', 'end');

	# check the last several letters, where suggestion based on
	my $key_word = Tcl2Perl($text);
	if ($key_word =~ /[\s,.*]+$|^[\s,.*]*$/) {
		$v_suggest_lbox->lower();
		$h_suggest_lbox->lower();
		$is_suggesting = 0;

		# this is a patch that helps status label recover from history
		$status = "Root: $show_root_dir";

		return 1;
	}

	# some character may infect the regexp
	$key_word =~ s/[.*()\\\/]//g;

	# there is something we only accept :)
	my @words = ($key_word =~ /[0-9a-zA-Z\x80-\xff]+/g);

	my $suggest_num = 0;
	foreach (@suggest_words) {
		# this is for delete regexp warning
		next unless scalar(@words);

		# compare the first letter first!! we focus on the last word user inputs
		if (/^$words[$#words]/) {
			my $suggest = Perl2Tcl($_);
			$v_suggest_lbox->_insertEnd("$suggest");
			$h_suggest_lbox->_insertEnd("$suggest");
			$suggest_num++;
		}

		# the upper limit of suggestion
		last if 10 <= $suggest_num;
	}

	# if there is no suggestion, just hide the suggest listbox
	unless ($suggest_num) {
		$v_suggest_lbox->lower();
		$h_suggest_lbox->lower();
		$is_suggesting = 0;
	} else {
		# if suggesting or all the text is meaningless, then won't raise
		unless ($is_suggesting or $text =~ /[\s,.*]+$/) {
			$v_suggest_lbox->raise();
			$h_suggest_lbox->raise();
			$is_suggesting = 1;
		}
	}

	$int->update();
	1;
}

sub clear_suggestion {
	$v_suggest_lbox->_delete('0', 'end');
	$h_suggest_lbox->_delete('0', 'end');

	$v_suggest_lbox->lower();
	$h_suggest_lbox->lower();
	$is_suggesting = 0;

	1;
}

# additional function show history
# will store history for a while
sub show_history {
	# don't forget to clear first
	clear_suggestion();

	$status = "Show search history . . .";


	# delete reduplicate history
	my %tmp_hash = ();
	my @historys = grep { ++$tmp_hash{$_} < 2 } @historys;

	foreach (@historys) {
			$v_suggest_lbox->_insertEnd("$_");
			$h_suggest_lbox->_insertEnd("$_");
	}

	unless (scalar (@historys)) {
		$status = "No history . . .";
	}

	$v_suggest_lbox->raise();
	$h_suggest_lbox->raise();

	1;
}

###### more info ######

my @cur_items = ();
my @more_file = ();

# main used widgets
my $more = $int->widget('.more', 'frame');
my $more_scroll = $int->widget('.more.left.scroll', 'scrollbar');
my $more_result = $int->widget('.more.left.result', 'canvas');
my $more_result_show = $int->widget('.more.left.result.show', 'frame');
my $more_result_prev = $int->widget('.more.left.result.preview', 'text');

# preview
my $last_prer = "";

# more result filter
my @more_filtered_file = ();
my $more_filter_string = "";
my $more_filter_curlen = 0;

# file types
my $isaudio = 1;
my $isphoto = 1;
my $isdoc = 1;
my $isfolder = 1;
my $iszip = 1;
my $isfile = 1;
$int->widget('.more.right.type.frame.audio', 'checkbutton')->
  configure(-variable => \$isaudio, -command => sub{more_change_type('audio')});
$int->widget('.more.right.type.frame.photo', 'checkbutton')->
  configure(-variable => \$isphoto, -command => sub{more_change_type('photo')});
$int->widget('.more.right.type.frame.doc', 'checkbutton')->
  configure(-variable => \$isdoc, -command => sub{more_change_type('doc')});
$int->widget('.more.right.type.frame.folder', 'checkbutton')->
  configure(-variable => \$isfolder, -command => sub{more_change_type('folder')});
$int->widget('.more.right.type.frame.zip', 'checkbutton')->
  configure(-variable => \$iszip, -command => sub{more_change_type('zip')});
$int->widget('.more.right.type.frame.file', 'checkbutton')->
  configure(-variable => \$isfile, -command => sub{more_change_type('file')});

sub more_change_type {
	my $type = shift;

	if ($type eq 'audio') {
		if ($isaudio) {
			foreach (@sorted_file) {
				push @more_file, $_ if is_audio_file($_);
			}
			more_sort_files();

		} else {
			my @tmp_more_file = @more_file;
			my $num = 0;
			foreach my $file (@tmp_more_file) {
				 if (is_audio_file($file)) {
					 splice(@more_file, $num, 1);
					 next;
				 }
				 $num++;
			}
		}
	} elsif ($type eq 'photo') {
		if ($isphoto) {
			foreach (@sorted_file) {
				push @more_file, $_
				  if is_photo_file($_);
			}
			more_sort_files();

		} else {
			my @tmp_more_file = @more_file;
			my $num = 0;
			foreach my $file (@tmp_more_file) {
				 if (is_photo_file($file)) {
					 splice(@more_file, $num, 1);
					 next;
				 }
				 $num++;
			}
		}
	} elsif ($type eq 'doc') {
		if ($isdoc) {
			foreach (@sorted_file) {
				push @more_file, $_ if is_doc_file($_);
			}

			more_sort_files();
		} else {
			my @tmp_more_file = @more_file;
			my $num = 0;
			foreach my $file (@tmp_more_file) {
				 if (is_doc_file($file)) {
					 splice(@more_file, $num, 1);
					 next;
				 }
				 $num++;
			}
		}
	} elsif ($type eq 'folder') {
		if ($isfolder) {
			foreach (@sorted_file) {
				push @more_file, $_ if -d $_;
			}

			more_sort_files();
		} else {
			my @tmp_more_file = @more_file;
			my $num = 0;
			foreach my $file (@tmp_more_file) {
				 if (-d $file) {
					 splice(@more_file, $num, 1);
					 next;
				 }
				 $num++;
			}
		}
	} elsif ($type eq 'zip') {
		if ($iszip) {
			foreach (@sorted_file) {
				push @more_file, $_ if is_zip_file($_);
			}

			more_sort_files();
		} else {
			my @tmp_more_file = @more_file;
			my $num = 0;
			foreach my $file (@tmp_more_file) {
				 if (is_zip_file($file)) {
					 splice(@more_file, $num, 1);
					 next;
				 }
				 $num++;
			}
		}
	} else {
		if ($isfile) {
			foreach (@sorted_file) {
				push @more_file, $_ if (is_file_file($_));
			}
			more_sort_files();
		} else {
			my @tmp_more_file = @more_file;
			my $num = 0;
			foreach my $file (@tmp_more_file) {
				 if (is_file_file($file)) {
					 splice(@more_file, $num, 1);
					 next;
				 }
				 $num++;
			}
		}
	}

	# notify result filter if necessary
	more_filter_result() if $more_filter_curlen;

	# update the scroller and more information window
	more_update_all();

	1;
}

# sort files
my $sortvar = 'SCORE';
my $sortdir = 'down';   # sort from high to low

my $sort_up = $int->widget('.more.right.sort.choose.up', 'button');
my $sort_down = $int->widget('.more.right.sort.choose.down', 'button');

$sort_up->configure(-command =>
    sub {
		$sortdir = 'up';
		$sort_up->configure(-state => 'disabled');
		$sort_down->configure(-state => 'normal');
		more_sort_files();

		# update the scroller and more information window
		more_update_all();
	}
);

$sort_down->configure(-command =>
    sub {
		$sortdir = 'down';
		$sort_up->configure(-state => 'normal');
		$sort_down->configure(-state => 'disabled');
		more_sort_files();

		# update the scroller and more information window
		more_update_all();
	}
);

$int->widget('.more.right.sort.choose.cbox', 'combobox')->
  configure(-textvariable => \$sortvar);
$int->widget('.more.right.sort.choose.cbox', 'combobox')->
  # Baozi FOUND THIS EVENT!!!
  bind('<FocusIn>' => sub {
		   more_sort_files();

		   # update the scroller and more information window
		   more_update_all();
	   }
   );

sub more_sort_files {
	if ($sortvar eq 'SCORE') {
		# cost more space but save time!!
		my %tmp_file;
		# build a hash to store original info --- the value is unnecessary
		foreach (@more_file) {$tmp_file{$_} = 0};
		@more_file = ();
		foreach (@sorted_file) {
			if(defined($tmp_file{$_})) {
				if ($sortdir eq 'up') { unshift @more_file, $_ }
				else {  push @more_file, $_	}
			}
		}
		# old!! cost time and space
#		my @tmp_file = @more_file;
#		@more_file = ();
#		foreach my $file (@sorted_file) {
#			my $index = 0;
#			foreach (@tmp_file) {
#				if ($_ eq $file) {
#					if ($sortdir eq 'up') { unshift @more_file, $_ }
#					else {  push @more_file, $_	}
#					splice (@tmp_file, $index, 1);
#					last;
#				}
#				$index++;
#			}
#		}
	} elsif ($sortvar eq 'NAME') {
		my %tmp_file;
		foreach (@more_file) {
			my ($vol, $dir, $file) = File::Spec->splitpath( "$_" );
			$tmp_file{$_} = $file;
		}

		# IMPORTANT!! local subroutine can use local variables
#		sub more_sort_name_up {$a cmp $b};
#		sub more_sort_name_down {$b cmp $a};
		if($sortdir eq 'up') {
			@more_file = sort 
			  {$tmp_file{$a} cmp $tmp_file{$b}} (keys %tmp_file);
		} else {
			@more_file = sort 
			  {$tmp_file{$b} cmp $tmp_file{$a}} (keys %tmp_file);
		}

	} elsif ($sortvar eq 'DATE') {
		my %tmp_date;

		# collect time information
		foreach (@more_file) {
			my $tmp = $_;
			# process zip file
			if (/\.zip[\/\\]/i)  {$tmp =~ s/zip[\/\\].*$/zip/ }
			# pre handle calculate information
			if (-e "$tmp") { $tmp_date{$_} = (stat("$tmp"))[9] }
			else { $tmp_date{$_} = 0 }
		}
		# IMPORTANT!! Soooo beautifully using anonymous in-line sub
		if($sortdir eq 'up') {
			@more_file = sort
			  {$tmp_date{$a} <=> $tmp_date{$b}} (keys %tmp_date);
		} else {
			@more_file = sort
			  {$tmp_date{$b} <=> $tmp_date{$a}} (keys %tmp_date);
		}
	} elsif ($sortvar eq 'SIZE') {
		my %tmp_size;

		# collect time information
		foreach (@more_file) {
			my $tmp = $_;
			# process zip file
			if (/\.zip[\/\\]/i)  {$tmp =~ s/zip[\/\\].*$/zip/ }
			# pre handle calculate information
			if (-e "$tmp") { $tmp_size{$_} = (stat("$tmp"))[7] }
			else { $tmp_size{$_} = 0 }
		}

		if($sortdir eq 'up') {
			@more_file = sort
			  {$tmp_size{$a} <=> $tmp_size{$b}} (keys %tmp_size);
		} else {
			@more_file = sort
			  {$tmp_size{$b} <=> $tmp_size{$a}} (keys %tmp_size);
		}
    } else {
        # do nothing, wait for extend
    }

	1;
}

# net result
my $net_lbox = $int->widget('.more.right.net.lbox', 'listbox');
my $net_flag = 'none';
my %baidu_results;
my %yahoo_results;

$int->widget('.vertical.shell.moreinfo', 'label')->bind('<ButtonRelease-1>',
    sub {
		if (scalar(@sorted_file)) {
			# update windows and scroller at the first time
			unless (@more_file) {
				@more_file = @sorted_file;
				more_update_all();
			}

			$more->state('normal');
		}
	}
);

$int->widget('.horizontal.shell.moreinfo', 'label')->bind('<ButtonRelease-1>',
    sub {
		if (scalar(@sorted_file)) {
			# update windows and scroller at the first time
			unless (@more_file) {
				@more_file = @sorted_file;
				more_update_all();
			}

			$more->state('normal');
		}
	}
);

# result filter enter
my $more_filter_ent = $int->widget('.more.right.filter.enter', 'entry');
$more_filter_ent->configure(-textvariable => \$more_filter_string);
$more_filter_ent->bind('<KeyRelease>', sub { more_filter_result() });

sub more_filter_result {
	# reset the filtered files
	unless ($more_filter_curlen) { @more_filtered_file = () }

	my $strlen = length($more_filter_string);

	# fit for different platforms
	my $filter_string;
    if ($^O =~ /win/i) {
        $filter_string = encode($charset, $more_filter_string);
    } else {
        $filter_string = encode($charset, $more_filter_string);
    }
	# IMPORTANT!!! these characters may cause problem when regexp
	$filter_string =~ s/\\/\\\\/g;
	$filter_string =~ s/([*.?()])/\\$1/g;


	if ($strlen > $more_filter_curlen) {
		# add string
		my $num = 0;
		my @tmp_file = @more_file;
		foreach my $file (@tmp_file) {
			# delete item from current results

			unless ($file =~ /$filter_string/i) {
				splice(@more_file, $num, 1);
				push(@more_filtered_file, $file);
				next;
			}
			$num++;
		}
	} elsif ($strlen < $more_filter_curlen) {
		# delete string
		my $num = 0;
		my @tmp_file = @more_filtered_file;
		foreach my $file (@tmp_file) {
			# recover item from filtered results
			if ($file =~ /$filter_string/i) {
				splice(@more_filtered_file, $num, 1);
				push(@more_file, $file);
				next;
			}
			$num++;
		}
		more_sort_files();
	} else {
		# equal ! it only occurs when type changes
		unless($isaudio) {
			my @tmp_file = @more_filtered_file;
			my $num = 0;
			foreach my $tmp (@tmp_file) {
				if (is_audio_file($tmp)) {
					splice(@more_filtered_file, $num, 1);
					next;
				}
				$num++;
			}
		}
		unless($isphoto) {
			my @tmp_file = @more_filtered_file;
			my $num = 0;
			foreach my $tmp (@tmp_file) {
				if (is_photo_file($tmp)) {
					splice(@more_filtered_file, $num, 1);
					next;
				}
				$num++;
			}
		}
		unless($isdoc) {
			my @tmp_file = @more_filtered_file;
			my $num = 0;
			foreach my $tmp (@tmp_file) {
				if (is_doc_file($tmp)) {
					splice(@more_filtered_file, $num, 1);
					next;
				}
				$num++;
			}
		}
		unless($isfolder) {
			my @tmp_file = @more_filtered_file;
			my $num = 0;
			foreach my $tmp (@tmp_file) {
				if (-d $tmp) {
					splice(@more_filtered_file, $num, 1);
					next;
				}
				$num++;
			}
		}
		unless($iszip) {
			my @tmp_file = @more_filtered_file;
			my $num = 0;
			foreach my $tmp (@tmp_file) {
				if (is_zip_file($tmp)) {
					splice(@more_filtered_file, $num, 1);
					next;
				}
				$num++;
			}
		}
		unless($isfile) {
			my @tmp_file = @more_filtered_file;
			my $num = 0;
			foreach my $tmp (@tmp_file) {
				if (is_file_file($tmp)) {
					splice(@more_filtered_file, $num, 1);
					next;
				}
				$num++;
			}
		}
	}

	# update current filter string length
	$more_filter_curlen = $strlen;

	# update window
	more_update_all();

	# highlighting the filtered words
	more_filter_highlight($filter_string);

	1;
}

sub more_filter_highlight {
	my $string = shift;
	$string = Perl2Tcl($string);

	foreach my $item (@cur_items) {
		my @items = @{ $item };
		# the third(0, 1, 2...) one is the text of path
		my $begin = $items[2]->search("$string",  '0.0');

		last unless $begin;

		my @begins = split(/\./, $begin);
		my $end = $begins[1]+length($string);
		$items[2]->configure(-state => 'normal');
		$items[2]->tag('add', 'highlightline', "$begin", "$begins[0].$end");
		$items[2]->tagConfigure('highlightline', -foreground => 'red');
		$items[2]->configure(-state => 'disabled');
		# there is a bug, letter case difference will cause the word not highlight
	}
	$more->update();

	1;
}

# control the scroller all by myself
$more_scroll->bind('<ButtonRelease-1>',
    sub {
		my @pos =  split/\s/, $more_scroll->get();
		more_update( int(scalar(@more_file)*$pos[0]) );
	}
);
$more_scroll->bind('<B1-Motion>',
    sub {
		my @pos =  split/\s/, $more_scroll->get();
		more_update( int(scalar(@more_file)*$pos[0]) );
	}
);

# more toplevel init - create six items
for (1..6) {
	my @items = ();

	# create a frame for each item
	# 0 --- LabelFrame --- file name
	# 1 --- label --- icon
	# 2 --- text --- path dir
	# 3 --- label --- date
	# 4 --- label --- size
	# 5 --- button --- preview info
	my $item = $more_result_show->Frame(
		-bg => 'white',
	)->pack(
		-in => $more_result_show,
		-anchor => 'nw',
		-pady => 10,
	);
	my $widget = $item->LabelFrame(
		-bg => 'white',
		-fg => 'blue',
	)->pack(
		-in => $item,
		-side => 'left',
		-anchor => 'nw',
	);
	push (@items, $widget);
	# file/dire type icon
	my $subicon = $widget->Label(
		-bg => 'white',
	);
	$subicon->pack(
		-in => $widget,
		-side => 'left',
		-anchor => 'center'
	);
	push (@items, $subicon);
	my $subwidget = $widget->Frame(
		-bg => 'white',
	)->pack(
		-in => $widget,
		-side => 'left',
	);
	# file path
	my $subtext = $subwidget->Text(
		-height => 2,
		-width => 39,
		-bg => 'white',
		-borderwidth => 0,
		-wrap => 'char',
	)->pack(
		-in => $subwidget,
		-anchor => 'nw',
	);
	push (@items, $subtext);
	$subtext->configure(-state => 'disabled');
	# date and size
	my $subsubwidget = $subwidget->Frame(
		-bg => 'white',
	)->pack(
		-in => $subwidget,
		-anchor => 'nw',
	);
	my $subsubdate = $subsubwidget->Label(
		-bg => 'white',
		-text => '',
	)->pack(
		-in => $subsubwidget,
		-anchor => 'nw',
		-side => 'left',
	);
	push (@items, $subsubdate);
	my $subsubsize = $subsubwidget->Label(
		-width => 12,
		-bg => 'white',
	)->pack(
		-in => $subsubwidget,
		-anchor => 'nw',
		-side => 'left',
	);
	push (@items, $subsubsize);
	# more info
	my $infobtn = $item->Button(
		-text => '>',
		-width => 0,
		-height => 4,
		-padx => 0,
		-pady => 0,
		-relief => 'flat',
		-bg => 'white',
	)->pack(
		-in => $item,
		-side => 'left',
		-anchor => 's',
	);
	push (@items, $infobtn);

	# record created widget
	push (@cur_items, \@items);
}
# end of more init

sub more_clear {
	foreach my $item (@cur_items) {
		my @items = @{ $item };

		# update labelframe file name
		$items[0]->configure(-text => '');

		# bind label icon
		$items[1]->configure(-image => '');
		$items[1]->bind('<Double-Button-1>', sub {});

		# update text path
		$items[2]->configure(-state => 'normal');
		$items[2]->delete('0.0', 'end');
		$items[2]->configure(-state => 'disabled');

		# update time
		$items[3]->configure(-text => '');

		# update size
		$items[4]->configure(-text => '');

		# update label arrow
		$items[5]->configure(
			-text => '>',
			-bg => 'white',
			-command => sub {},
		);
	}

	# clear more preview
	more_list_clear();
}

sub more_reset {
	more_clear();

	# clear net result listbox
	$net_lbox->_delete(0, 'end');
	$net_flag = "none";
	%baidu_results = ();
	%yahoo_results = ();

	# clear more result
	@more_file = ();

	# clear filter string(the filtered items will clear when first init)
	$more_filter_string = "";

	# close more information window
	$more->state('withdraw');

	1;
}

sub more_update {
	my $index = shift;

	foreach my $item (@cur_items) {
		more_update_item($item, $more_file[$index])
		  if defined($more_file[$index]);
		$index++;
	}
}

sub more_update_all {
	more_clear();
	my $region = 100 * scalar(@more_file);
	$more_result->configure(-scrollregion => "0 0 $region $region");
	$more_result->yview('moveto', '0.0');
	more_update(0);
	$more->update();
	1;
}

sub more_update_item {
	my $arg = shift;
	my $path = shift;

	my @items = @{ $arg };

	my ($vol, $dir, $file) = File::Spec->splitpath( "$path" );
	my $tmp_path;

	# process zip file
	if ($path =~ /\.zip[\/\\]/i) {
		$tmp_path = $dir;
		$tmp_path =~ s/[\/\\]$//;
	} else {
		$tmp_path = $path;
	}

	my $date;
	my $size;
	# pre handle calculate information
	if (-e $tmp_path) {
		my @statinfo = stat("$tmp_path");
		$date = strftime "%Y-%m-%d %H:%M:%S", (localtime $statinfo[9])[0..5];
		$size = $statinfo[7];
		my $offset = 0;
		while ($size > 1023) {$size = sprintf "%0.2f", ($size/1024); $offset++};
		$size = "$size".(qw(B KB MB GB TB))[$offset];
	} else {
		$date = 'Unknown';
		$size = '0B'
	}

	# update labelframe file name
	my $file_label = $file;
	$file_label =~ s/^(.{30}).*$/$1.../ if 30 < length($file_label);
	$items[0]->configure(-text => Perl2Tcl($file_label));

	# bind label icon
	$items[1]->bind('<Double-Button-1>',
	    sub {
			if ($^O =~ /win/i) {
				$tmp_path =~ s/\\\\/\\/g; 
				$tmp_path =~ s/\//\\/g; 
				warn "$tmp_path\n";
				# on windows os
				if (-d "$tmp_path") {
					# open dir
					`explorer "$tmp_path"`;
				} else {
					# open file
					system("$tmp_path");
				}
			} else {
				# on linux os
				`xdg-open "$tmp_path"`;
			}
		},
	);

	# update text path
	$items[2]->configure(-state => 'normal');
	$items[2]->delete('0.0', 'end');
	$items[2]->_insertEnd(Perl2Tcl($path));
	$items[2]->configure(-state => 'disabled');

	# update time
	$items[3]->configure(-text => "Date: $date");

	# update size
	$items[4]->configure(-text => "Size: $size");

	# update label arrow
	if ($last_prer eq $path) {
		$items[5]->configure(
			-text => '<',
			-bg => '#bbf',
		);
	} else {
		$items[5]->configure(
			-text => '>',
			-bg => 'white',
		);
	}

	# update label icon and label arrow
	if (-d $tmp_path) {
		# folder
		$items[1]->configure(-image => $folder_icon);
		$items[5]->configure(
			-command =>
			  sub {
				  if ('>' eq $items[5]->cget('-text')) {
					  # list file content
					  more_list_folder($tmp_path);
					  $last_prer = $path;

					  # change button state
					  $items[5]->configure(
						  -text => '<',
						  -bg => '#eef',
					  );
				  } else {
					  more_list_clear();
					  $last_prer = "";

					  # reset button state
					  $items[5]->configure(
						  -text => '>',
						  -bg => 'white',
					  );
				  }
			  }
		  );
	} elsif (is_zip_file($tmp_path)) {
		# zip
		$items[1]->configure(-image => $zip_icon);
		$items[5]->configure(
			-command =>
			  sub {
				  if ('>' eq $items[5]->cget('-text')) {
					  # list file content
					  more_list_zip($tmp_path);
					  $last_prer = $path;

					  # change button state
					  $items[5]->configure(
						  -text => '<',
						  -bg => '#eef',
					  );
				  } else {
					  more_list_clear();
					  $last_prer = "";

					  # reset button state
					  $items[5]->configure(
						  -text => '>',
						  -bg => 'white',
					  );
				  }
			  }
		  );
	} elsif (is_photo_file($tmp_path)) {
		# photo
		$items[1]->configure(-image => $photo_icon);
		$items[5]->configure(
			-command =>
			  sub {
				  if ('>' eq $items[5]->cget('-text')) {
					  # list file content
					  more_list_photo($tmp_path);
					  $last_prer = $path;

					  # change button state
					  $items[5]->configure(
						  -text => '<',
						  -bg => '#eef',
					  );
				  } else {
					  more_list_clear();
					  $last_prer = "";

					  # reset button state
					  $items[5]->configure(
						  -text => '>',
						  -bg => 'white',
					  );
				  }
			  }
		  );
	} elsif (is_audio_file($tmp_path)) {
		# audio
		$items[1]->configure(-image => $audio_icon);
		$items[5]->configure(
			-command =>
			  sub {
				  if ('>' eq $items[5]->cget('-text')) {
					  # list file content
					  more_list_audio($tmp_path);
					  $last_prer = $path;

					  # change button state
					  $items[5]->configure(
						  -text => '<',
						  -bg => '#eef',
					  );
				  } else {
					  more_list_clear();
					  $last_prer = "";

					  # reset button state
					  $items[5]->configure(
						  -text => '>',
						  -bg => 'white',
					  );
				  }
			  }
		  );
	} elsif (is_doc_file($tmp_path)) {
		# document
		$items[1]->configure(-image => $doc_icon);
		$items[5]->configure(
			-command =>
			  sub {
				  if ('>' eq $items[5]->cget('-text')) {
					  # list file content
					  more_list_doc($tmp_path);
					  $last_prer = $path;

					  # change button state
					  $items[5]->configure(
						  -text => '<',
						  -bg => '#eef',
					  );
				  } else {
					  more_list_clear();
					  $last_prer = "";

					  # reset button state
					  $items[5]->configure(
						  -text => '>',
						  -bg => 'white',
					  );
				  }
			  }
		  );
	} elsif (is_file_file($tmp_path)) {
		$items[1]->configure(-image => $file_icon);
		$items[5]->configure(
			-command =>
			  sub {
				  if ('>' eq $items[5]->cget('-text')) {
					  # list file content
					  more_list_file($tmp_path);
					  $last_prer = $path;

					  # change button state
					  $items[5]->configure(
						  -text => '<',
						  -bg => '#eef',
					  );
				  } else {
					  more_list_clear();
					  $last_prer = "";

					  # reset button state
					  $items[5]->configure(
						  -text => '>',
						  -bg => 'white',
					  );
				  }
			  }
		  );
	}

	1;
}

sub more_list_clear {
	$more_result_prev->configure(-state => 'normal');
	$more_result_prev->delete('1.0', 'end');
	$more_result_prev->configure(-bg => 'white');
	$more_result_prev->configure(-state => 'disabled');
	$last_prer = "";
}

sub more_list_photo {
	my $file = shift;

	$more_result_prev->configure(-state => 'normal');

	foreach (@cur_items) {
		my @items = @{$_};
		my $cur_prer = Tcl2Perl($items[2]->get('0.0', 'end'));

		# IMPORTANT!! delete \n at end of text -_-||
		chomp($cur_prer);

		if ($last_prer eq $cur_prer) {
			$items[5]->configure(
				-text => '>',
				-bg => 'white',
			);
		}
	}

	# clear last preview
	$more_result_prev->delete('0.0', 'end');

	unless (-e $file) {
		$more_result_prev->_insertEnd("This photo has been moved or deleted");
		$more_result_prev->configure(-bg => '#eef');
		$more_result_prev->configure(-state => 'disabled');
		return 0;
	}

	# try to create image
	my $tmp_file = Perl2Tcl($file);

	my $tmp_img = $int->imageCreate( 'photo', -file => "$tmp_file");
	$more_result_prev->_imageCreate('end', -image => $tmp_img);

	$more_result_prev->configure(-bg => '#eef');
	$more_result_prev->configure(-state => 'disabled');

	1;
}

sub more_list_doc {
	my $file = shift;

	$more_result_prev->configure(-state => 'normal');

	foreach (@cur_items) {
		my @items = @{$_};
		my $cur_prer = Tcl2Perl($items[2]->get('0.0', 'end'));

		# IMPORTANT!! delete \n at end of text -_-||
		chomp($cur_prer);

		if ($last_prer eq $cur_prer) {
			$items[5]->configure(
				-text => '>',
				-bg => 'white',
			);
		}
	}

	# clear last preview
	$more_result_prev->delete('0.0', 'end');

	unless (-e "$file") {
		$more_result_prev->_insertEnd('This file has been moved or deleted!');
		$more_result_prev->configure(-bg => '#eef');
		$more_result_prev->configure(-state => 'disabled');
		return 0;
	}
	my @content;

	# some types that supported
	if ($file =~ /\.pdf/i) {
		my $pdf = CAM::PDF->new("$file");
		my $page_num = $pdf->numPages();
		my $show_num = 10;
		push @content, "#INFO: This pdf has $page_num pages\n\n";
		foreach (1..$page_num) {
			push @content, $pdf->getPageText($_);
			last if $show_num < $_;
		}
	} elsif(0) {
	} else {
	}


	# insert into preview text
	foreach ( @content ) {
		my $one_info = encode('utf-8', $_);
		$one_info = Perl2Tcl($one_info);
		$more_result_prev->_insertEnd($one_info);
	}

	$more_result_prev->configure(-bg => '#eef');
	$more_result_prev->configure(-state => 'disabled');

	1;
}

sub more_list_audio {
	my $file = shift;

	$more_result_prev->configure(-state => 'normal');

	foreach (@cur_items) {
		my @items = @{$_};
		my $cur_prer = Tcl2Perl($items[2]->get('0.0', 'end'));

		# IMPORTANT!! delete \n at end of text -_-||
		chomp($cur_prer);

		if ($last_prer eq $cur_prer) {
			$items[5]->configure(
				-text => '>',
				-bg => 'white',
			);
		}
	}

	# clear last preview
	$more_result_prev->delete('0.0', 'end');

	unless (-e "$file") {
		$more_result_prev->_insertEnd('This file has been moved or deleted!');
		$more_result_prev->configure(-bg => '#eef');
		$more_result_prev->configure(-state => 'disabled');
		return 0;
	}
	my @content;
	# read audio id3 info
	if ($file =~ /\.mp3$|\.ogg$/i) {
		my $song = AudioFile::Info->new($file);
		push @content, "Title : ", $song->title, "\n";
		push @content, "Artist : ",  $song->artist, "\n";
		push @content, "Album : ",  $song->album, "\n";
		push @content, "Track : ",  $song->track, "\n";
		push @content, "Year : ",  $song->year, "\n";
		push @content, "Genre : ",  $song->genre, "\n";

	} elsif ($file =~ /\.mp4$|\.m4[ap]$|\.3gp$/i) {
		my $tag = get_mp4tag($file);
		push @content,  'Album : ', $tag->{ALB}, "\n";
		push @content, 'Artist : ', $tag->{ART}, "\n";
		push @content, 'Title : ', $tag->{NAM}, "\n";
		push @content, 'Author : ', $tag->{WRT}, "\n";
		push @content, 'Encoder : ', $tag->{TOO}, "\n";
		push @content, 'Genre : ', $tag->{GNRE}, "\n";
		push @content, 'Year : ', $tag->{DAY}, "\n";
		push @content, 'Copyright : ', $tag->{CPRT}, "\n";
		push @content, 'Comment : ', $tag->{CMT}, "\n";
		my $info = get_mp4info($file);
		push @content, 'Bitrate : ', $info->{BITRATE}, "\n";
		push @content, 'Frequency : ', $info->{FREQUENCY}, "\n";
		push @content, 'Size : ', $info->{SIZE}, "\n";
		push @content, 'Time : ', $info->{TIME}, "\n";
		push @content, 'Encoding : ', $info->{ENCODING}, "\n";
	} else {
		push @content,
		  'Sorry, it is now only available for mp3/ogg/mp4/m4a/m4p/3gp files...';
		push @content, 'Other types of audio files are not fully supported!';
	}

	foreach ( @content ) {
		my $one_info = encode('utf-8', $_);
		$one_info = Perl2Tcl($one_info);
		$more_result_prev->_insertEnd($one_info);
	}

	$more_result_prev->configure(-bg => '#eef');
	$more_result_prev->configure(-state => 'disabled');

	1;
}

sub more_list_file {
	my $file = shift;

	$more_result_prev->configure(-state => 'normal');

	foreach (@cur_items) {
		my @items = @{$_};
		my $cur_prer = Tcl2Perl($items[2]->get('0.0', 'end'));

		# IMPORTANT!! delete \n at end of text -_-||
		chomp($cur_prer);

		if ($last_prer eq $cur_prer) {
			$items[5]->configure(
				-text => '>',
				-bg => 'white',
			);
		}
	}

	# clear last preview
	$more_result_prev->delete('0.0', 'end');

	# read new file content
	my @content;
	if (-e $file) {
		open my $fh, '<', "$file";
	    @content = <$fh>;
		close $fh;
	} else {
		push @content, 'This file has been moved or deleted!';
	}

	my $num = 0;
	if (scalar(@content)) {
		# add new preivew
		foreach (@content) {
			$_ = Perl2Tcl($_);
			$more_result_prev->_insertEnd($_);

			# only preview the first 100 lines
			last if 100 <= $num++;
		}
	} else {
		$more_result_prev->_insertEnd('This is an empty file!');
	}

	$more_result_prev->configure(-bg => '#eef');
	$more_result_prev->configure(-state => 'disabled');

	1;
}

sub more_list_folder {
	my $folder = shift;

	$more_result_prev->configure(-state => 'normal');

	foreach (@cur_items) {
		my @items = @{$_};
		my $cur_prer = Tcl2Perl($items[2]->get('0.0', 'end'));

		# IMPORTANT!! delete \n at end of text -_-||
		chomp($cur_prer);

		if ($last_prer eq $cur_prer) {
			$items[5]->configure(
				-text => '>',
				-bg => 'white',
			);
		}
	}

	# clear last preview
	$more_result_prev->delete('0.0', 'end');

	# add new preivew
	my @content;
	if (-e $folder) {
		opendir(DIR, "$folder");
		@content = readdir DIR;
		close DIR;
	} else {
		push @content, 'This Directory has been moved or deleted!';
	}

	foreach (sort @content) {
		$_ = Perl2Tcl($_);
		$more_result_prev->_insertEnd("$_\n");
	}

	$more_result_prev->configure(-bg => '#eef');
	$more_result_prev->configure(-state => 'disabled');

	1;
}

sub more_list_zip {
	my $zipfile = shift;

	$more_result_prev->configure(-state => 'normal');

	foreach (@cur_items) {
		my @items = @{$_};
		my $cur_prer = Tcl2Perl($items[2]->get('0.0', 'end'));

		# IMPORTANT!! delete \n at end of text -_-||
		chomp($cur_prer);

		if ($last_prer eq $cur_prer) {
			$items[5]->configure(
				-text => '>',
				-bg => 'white',
			);
		}
	}

	# clear last preview
	$more_result_prev->delete('0.0', 'end');

	my $zip = Archive::Zip->new();
	my $status = $zip->read($zipfile);
	my @content = ();

	 # only support zip file now
	if ($zipfile =~ /\.zip$/) {
		if (AZ_OK == $status) {
			@content = $zip->memberNames();
		} else {
			push @content, 'This zip file has been moved or deleted!';
		}
	} else {
			push @content, 'Sorry, it is now only available for zip files...';
			push @content, 'Other types of compressed files are not fully supported!';
	}

	foreach (sort @content) {
		$_ = Perl2Tcl($_);
		$more_result_prev->_insertEnd("$_\n");
	}

	$more_result_prev->configure(-bg => '#eef');
	$more_result_prev->configure(-state => 'disabled');

	1;
}

# here are options on right window
$int->widget('.more.right.net.btnframe.baidu', 'button') ->configure(-command =>
   sub {
		$net_lbox->_delete(0, 'end');
		$net_lbox->_insertEnd("Searching from Baidu...");
		$more->update();

		# check if it can access to baidu
		if (ping(host => 'www.baidu.com')) {
			%baidu_results = Net::BaiduIt($text);

			$net_lbox->_delete(0, 'end');
			foreach (keys %baidu_results) {
				next if /^\s*$/;
				$net_lbox->_insertEnd($_);
			}
			$net_lbox->_insertEnd("More...");
			$net_flag = 'baidu';
		} else {
			$net_lbox->_delete(0, 'end');
			$net_lbox->_insertEnd("No network");
			$net_flag = 'none';
		}
	}
);

$int->widget('.more.right.net.btnframe.yahoo', 'button') ->configure(-command =>
   sub {
		$net_lbox->_delete(0, 'end');
		$net_lbox->_insertEnd("Searching from Yahoo...");
		$more->update();

		# check if it can access to yahoo
		if (ping(host => 'www.yahoo.cn')) {
			%yahoo_results = Net::YahooIt($text);
			$net_lbox->_delete(0, 'end');
			foreach (keys %yahoo_results) {
				next if /^\s*$/;
				$net_lbox->_insertEnd($_);
			}
			$net_lbox->_insertEnd("More...");
			$net_flag = 'yahoo';
		} else {
			$net_lbox->_delete(0, 'end');
			$net_lbox->_insertEnd("No network");
			$net_flag = 'none';
		}
	}
);

# set bind action
$net_lbox->bind('<Double-Button-1>' =>
     sub {
		 my $index = $net_lbox->curselection();
		 my $title = $net_lbox->get($index);

		 my $target = Tcl2Perl($text);

		 my $url = "";
		 if ($net_flag eq 'baidu') {
			 if ('More...' eq $title) {
				 $url = "http://www.baidu.com/s?wd=$target";
			 } else {
				 $url = $baidu_results{$title};
			 }
		 } elsif ($net_flag eq 'yahoo') {
			 if ('More...' eq $title) {
				 $url = "http://www.yahoo.cn/s?q=$target";
			 } else {
				 $url = $yahoo_results{$title};
			 }
		 } else {
			 # do nothing
		 }

		 open_url_link($url);

		 1;
	 }
 );

sub open_url_link {
	my $url = shift;

	if ($^O =~ /win/i) {
		# on windows os
		`explorer "$url"`;
	} else {
		# on linux os
		`xdg-open "$url"`;
	}

	1;
}

###### end of more info ######

$int->Eval(<<'READY');
set startload "Tap to start"
.vertical.start configure -state normal
READY

# start interpreter
$int->MainLoop;
############################################################

# perl to tcl encode
sub Perl2Tcl { encode('unicode', decode("$charset", shift)) }

# tcl to perl encode
sub Tcl2Perl { encode("$charset", decode('unicode', shift)) }

# perl to tcl encode
#sub Perl2Tcl { encode('unicode', decode('utf-8', shift)) }
# tcl to perl encode
#sub Tcl2Perl { encode('utf-8', decode('unicode', shift)) }
# Chinese to perl encode
#sub Chn2Perl { encode('utf-8', decode('euc-cn', shift)) }

# check input words
sub check_input {
	if ($text =~ /fuck|bitch|tmd|mlgb/i) {
		$text =~ s/(f)uck/$1***/gi;
		$text =~ s/(b)itch/$1****/gi;
		$text =~ s/(t)md/$1**/gi;
		$text =~ s/(m)lgb/$1***/gi;

		# keep update
		$v_ety_enter->configure(-textvariable => \$text);
		$h_ety_enter->configure(-textvariable => \$text);
	}

	1;
}

# open file or die or zip or anything
sub open_file {
	my $name = shift;
	my $index = shift;

	# special process on information item
	unless ($name =~ /^~/) {
		if ("No Information Avaiable" eq $name) {
			# won't process on no info warning
			return 1;
		} else {
			# will open root directory on other info
			$name = "~";
		}
	}

	my $coded_dir = encode("unicode", decode("$charset", $rootdir));

	# replace ROOT directory
	$name =~ s/^~/$coded_dir/;

	# stop at zip file if exists
	$name =~ s/(\.zip).*$/$1/g;

	my $file = Tcl2Perl($name);
#	my $file = $name;

	if (-e "$file") {
		if ($^O =~ /win/i) {

			$file =~ s/\\\\/\\/g; 
			$file =~ s/\//\\/g; 
			if (-d "$file") {
				# open dir

#				warn "$file\n";
				`explorer "$file"`;
			} else {
				# open file
				system("$file");
			}
		} else {
			# on linux os
			print "xdg-open $file\n";
			`xdg-open "$file"`;
		}
	} else {
		$v_lbox_rst->itemconfigure($index, -background => '#fcc');
		$h_lbox_rst->itemconfigure($index, -background => '#fcc');
	}

	1;
}

# result filter by ALL/FILE/DIRE/TEXT/BINARY
sub result_filter {

	# won't process when showing content result
    if ($scale) {
		return 0;
	};

	# delete former result in listbox
	$v_lbox_rst->_delete(0, 'end');
	$h_lbox_rst->_delete(0, 'end');

	my @files = ();
	my $infos = "";
	if ('ALL' eq $filter) {
		# show all no filter at all
		show_result();
		return 1;
	} elsif ('FILE' eq $filter) {
		$infos = 'File Searching Result:';
		foreach my $file (@sorted_file) {
			if (-f $file) { push @files, $file }
		}
	} elsif ('DIRE' eq $filter) {
		$infos = 'Directory Searching Result:';
		foreach my $file (@sorted_file) {
			if (-d $file) { push @files, $file }
		}
	} elsif ('TEXT' eq $filter) {
		$infos = 'Text Type Searching Result:';
		foreach my $file (@sorted_file) {
			if (-T $file) { push @files, $file }
		}
	} else {
		$infos = 'Binary Type Searching Result:';
		foreach my $file (@sorted_file) {
			# considering the files in zip pack
			my $tmpfile = $file;
			$tmpfile =~ s/\.zip.*/.zip/;
			if (-B $tmpfile) {
				# empty file will be regarded as text file and binary file
				# so we must ignore the empty file as binary file
				next unless (stat $tmpfile)[7];
				push @files, $file;
			}
		}
	}

	$v_lbox_rst->_insertEnd($infos);
	$h_lbox_rst->_insertEnd($infos);
	$v_lbox_rst->itemconfigure(0, -background => '#bfb');
	$h_lbox_rst->itemconfigure(0, -background => '#bfb');

	foreach my $tmp (@files) {
		# root directory replace
		substr($tmp, 0, length($rootdir)) = "~";

		# turn perl encode into tcl encode type
		$tmp = Perl2Tcl($tmp);

		$v_lbox_rst->_insertEnd($tmp);
		$h_lbox_rst->_insertEnd($tmp);
	}

	1;
}

# recover caused action
sub recover_action {
	# enable search button
	$v_btn_search->configure(-state => 'normal');
	$h_btn_search->configure(-state => 'normal');

	1;
}

sub sort_desend { $result{$b} <=> $result{$a} }
sub show_result {
	# delete former result in listbox
	$v_lbox_rst->_delete(0, 'end');
	$h_lbox_rst->_delete(0, 'end');
	$scale = 0;
	$filter = 'ALL';

	# enable filter spinbox
	$v_filter_opt->configure('-state' => 'normal' );
	$h_filter_opt->configure('-state' => 'normal' );

	$v_lbox_rst->_insertEnd('File/Directory Searching Results:');
	$v_lbox_rst->itemconfigure(0, -background => '#bfb');
	$h_lbox_rst->_insertEnd('File/Directory Searching Results:');
	$h_lbox_rst->itemconfigure(0, -background => '#bfb');

	if (0 == scalar(keys %result)) {
		$v_lbox_rst->_insertEnd('No Information Available');
		$v_lbox_rst->itemconfigure(1, -background => '#fcc');
		$h_lbox_rst->_insertEnd('No Information Available');
		$h_lbox_rst->itemconfigure(1, -background => '#fcc');

		return 0;
	}

	@sorted_file = sort sort_desend (keys %result);
	my $index = 1;

	foreach my $file (@sorted_file) {
		my $tmpfile = $file;

		# root directory replace
		substr($tmpfile, 0, length($rootdir)) = "~";

		# turn perl encode into tcl encode type
		$tmpfile = Perl2Tcl($tmpfile);

		# insert file/dir name at the end of listbox
		$v_lbox_rst->_insertEnd($tmpfile);
		$h_lbox_rst->_insertEnd($tmpfile);

		# check if it is a directory
		if (-d $file) {
			$v_lbox_rst->itemconfigure($index, -background => '#eef');
			$h_lbox_rst->itemconfigure($index, -background => '#eef');
		} else {
			$v_lbox_rst->itemconfigure($index, -background => '#ffb');
			$h_lbox_rst->itemconfigure($index, -background => '#ffb');
		}

		$index++;
	}

	1;
}

sub show_content {
	# delete former result in listbox
	$v_lbox_rst->_delete(0, 'end');
	$h_lbox_rst->_delete(0, 'end');
	$scale = 1;

	# disable filter spinbox
	$v_filter_opt->configure('-state' => 'disabled' );
	$h_filter_opt->configure('-state' => 'disabled' );

	# print top information
	$v_lbox_rst->_insertEnd('Content Searching Results:');
	$v_lbox_rst->itemconfigure(0, -background => '#bfb');
	$h_lbox_rst->_insertEnd('Content Searching Results:');
	$h_lbox_rst->itemconfigure(0, -background => '#bfb');

	if (0 == scalar(@content_result)) {
		$v_lbox_rst->_insertEnd('No Information Available');
		$v_lbox_rst->itemconfigure(1, -background => '#fcc');
		$h_lbox_rst->_insertEnd('No Information Available');
		$h_lbox_rst->itemconfigure(1, -background => '#fcc');

		return 0;
	}

	my $index = 1;
	foreach my $file (@content_result) {
		my $tmp = $file;

		# root directory replace
		substr($tmp, 0, length($rootdir)) = "~";
#print "$file $tmp\n";
		# turn perl encode into tcl encode type
		$tmp = Perl2Tcl($tmp);

		# insert file/dir name at the end of listbox
		$v_lbox_rst->_insertEnd($tmp);
		$h_lbox_rst->_insertEnd($tmp);

		$v_lbox_rst->itemconfigure($index, -background => '#ffb');
		$h_lbox_rst->itemconfigure($index, -background => '#ffb');

		$index++;
	}

	1;

}

# press search button caused action
sub search_action {
	my $mode = shift;

	if ($text =~ /^\s*$/) {
		show_history();
		return;
	}

	# close more info window
	more_reset();

	# change status
	$status = "Searching . . .";

	# disable search button
	$v_btn_search->configure(-state => 'disabled');
	$h_btn_search->configure(-state => 'disabled');

	# update all widgets
	$int->update();

	# reset result
	reset_action();

	# IMPORTANT!! encode changed between tcl and perl
	my $input = Tcl2Perl($text);

	# record history
	unshift @historys, $text;

	# specific searching
	my $input_all = Tcl2Perl($includeall);
	my $input_not = Tcl2Perl($includenot);

	# judge by specific/fuzzy mode
	unless ($input =~ /^\s*\[regexp\](.*)$/) {
print "not!!!\n";
		if ($mode) {

			# IMPORTANT!! the content tag has been changed to Be Strict
			if ($content) {
				%result = Search::StrictSearchData
				  ($input, $input_all, $input_not, $casesen);
			} else {
				%result = Search::SearchData
				  ($input, $input_all, $input_not, $casesen);
			}

		} else {
			# fuzzy searching
			%result = Search::FuzzySearchData($input);
		}

		@content_result = Kino::SearchContentData($input) 
		  if (Kino::IsIndexExist());
	} else {
		%result = Search::RegexpSearchData
		  ($1, $input_all, $input_not);
	}

	# show result
	show_result();
$int->Eval(<<'SHOW');
set locked 1
raise .vertical.result
raise .horizontal.result
SHOW

	print Dumper (\%result);

	# recover from searching action
	recover_action($mode);

	# set status label
	my $rstnum = scalar(@sorted_file);
	$status = "Showing Results : $rstnum items in total . . .";

	1;
}

sub reset_action {
	%result = ();
	@sorted_file = ();
	@content_result = ();

	clear_suggestion();

	1;
}

# press clear button caused action
sub clear_action {
	my $mode = shift;

	# recover first for safety
	recover_action($mode);

	# set status label
	$status = "Root: $show_root_dir";

	reset_action();
	more_reset();

	# change status
	$text = "";

	# clear showed result
	$v_lbox_rst->_delete(0, 'end');
	$h_lbox_rst->_delete(0, 'end');
$int->Eval(<<'CLEAR');
lower .vertical.result
lower .horizontal.result
set locked 0
CLEAR

	# clear these only when specific searching
	if ($mode) {
		# reset options only in mode 1
		$includeall = "";
		$includenot = "";
		$casesen = 0;
		$content = 0;

$int->Eval(<<'CLEAROPT');
# don't forget the checkbutton
set is_casesen 0
set is_content 0

lower .vertical.shell.casesen
lower .vertical.shell.content
slide_out 3 $totalstep $totalstep $interval

lower .vertical.shell.includenot
lower .vertical.shell.includenotlbl
slide_out 2 $totalstep $totalstep $interval

lower .vertical.shell.includeall
lower .vertical.shell.includealllbl
slide_out 1 $totalstep $totalstep $interval
CLEAROPT


    } else {
		# do nothing for now
	}

	reset_action();

	1;
}

sub is_audio_file {
	my $target = shift;
	$target =~ s/\s*$//;

	if ($target =~
/\.mp[34]$|\.wm[av]$|\.wav$|\.og[ga]$|\.ap[el]$
|\.fl[a]*c$|\.aac$|\.aif[f]*$|\.wv$|\.m4[abpvr]$
|\.3gp$|\.3gp$|\.avi$|\.rm[v]*[b]*$|\.asf$/i) {
		return 1;
	} else {
		return 0;
	}
}

sub is_zip_file {
	my $target = shift;
	my ($vol, $dir, $fil) = File::Spec->splitpath( "$target" );
	$dir =~ s/\s*[\\\/]*$//;

	$target =~ s/\s*$//;

	if ($target =~
		  /\.zip$|\.rar$|\.7z$|\.gz$|\.tgz$|\.bz2$|\.xz$|\.tar$|\.lzma$|\.txz$/i
		  or 	$dir =~
			/\.zip$|\.rar$|\.7z$|\.gz$|\.tgz$|\.bz2$|\.xz$|\.tar$|\.lzma$|\.txz$/i) {
		return 1;
	} else {
		return 0;
	}
}

sub is_doc_file {
	my $target = shift;
	$target =~ s/\s*$//;

	if ($target =~
/\.pdf$|\.doc[x]*$|\.ppt[x]*$|\.xls[x]*$|\.pps$
|\.vsd$|\.xlt$|\.[f]*od[tspg]$|\.ot[tsp]$|\.sx[wcid]$
|\.st[wci]$|\.uo[ts]$|\.pot[m]*$|\.xml$|\.csv$/i) {
		return 1;
	} else {
		return 0;
	}
}

sub is_photo_file {
	my $target = shift;
	$target =~ s/\s*$//;
	 if ($target =~
		   /\.jpg$|\.gif$|\.png$|\.jpeg$|\.tiff$|\.bmp$|\.pcx$|\.tga$|\.exif$/i) {
		 return 1;
	 } else {
		 return 0;
	 }
}

sub is_file_file {
	my $target = shift;

	# plain text is mostly occurs
#	if (-T $target) {
#		return 1;
#	} else {
	# the rest of situation
	unless (is_audio_file($target) or is_photo_file($target) or
			  is_doc_file($target) or is_zip_file($target) or (-d $target)) {
		return 1;
	} else {
		return 0;
	}
	#	}
}

END { Index::StoreData; }

