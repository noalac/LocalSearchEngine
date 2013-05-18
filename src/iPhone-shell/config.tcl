# detecting OS platform
if { [regexp -nocase {windows} $tcl_platform(platform)] } {
	# on Windows
	set rottime 800


	# show result
	set vlboxwidth 38
	set vlboxheight 21
	
	set hlboxwidth 51
	set hlboxheight 10


} elseif { [regexp -nocase {unix} $tcl_platform(platform)] } {
	# on Linux / Unix / Mac OS ...
	set rottime 700

	# show result
	set vlboxwidth 31
	set vlboxheight 16

	set hlboxwidth 46
	set hlboxheight 8

	set vrstfont Sans
	set hrstfont Sans

} else {
	# default
}

# global setting
set bgwidth 392; # background width
set bgheight 744; # background height

set hbgwidth $bgheight; # bgw for horizontal
set hbgheight $bgwidth; # bgh for horizontal

# search button config
set sbtntext  Search
set sbtncolor 632

# theme options
# start up menu
set startx 31; # start up button x pos
set starty 120; # start up button y pos

# button on back
set backbgcolor #000
set backfgcolor #fff
set backtext iHelp
set backx 140
set backy 530

# vertical
set vrotbtnx 44; # rotate button x pos
set vrotbtny 146; # rotate button y pos
set vsbtnx 300; # search button x pos
set vsbtny 193; # search button y pos
set vclrbtnx 328; # clear button x pos
set vclrbtny $vrotbtny; # clear button y pos
set ventx 71; # enter entry x pos
set venty 199; # enter entry y pos
set vstatlblx 38; # status label x pos
set vstatlbly 119; # status label y pos

set vshowx 39; # show blocks x pos
set vshowy 238; # show blocks y pos

set ventwidth 210; # enter width

# horizontal
set hrotbtnx 144
set hrotbtny 52
set hsbtnx 538
set hsbtny 98
set hclrbtnx 575
set hclrbtny $hrotbtny
set hentx 166
set henty 103
set hstatlblx 135
set hstatlbly 22

set hshowx 137
set hshowy 147

set hentwidth 350; # enter width

# basic options configure
set optwidth 327; # option block width
set optheight 44; # option block height
set vopt1x 37; # opt1 x pos
set vopt1y 239; # opt1 y pos
set vopt2x $vopt1x
set vopt2y 287
set vopt3x $vopt1x
set vopt3y 334
set animorient 0; # the orientation
# 1 means left to right
# 0 means right to left

# option background color
set r 9
set g 9
set b 0

# include option
set vincludewidth 20
set vincludelbl 60

# include all
set vinallx 158
set vinally 250

# include not
set vinnotx $vinallx
set vinnoty 297

# case sensitive
set vcasex 55
set vcasey 344

# content search
set vcontx 195
set vconty $vcasey

# option animation
set interval 20; # opt animation interval
set totalstep 15; # between 1 ~ 15
set x0 $optwidth; # determine which direction
set xt $optwidth
set x0incr -[expr $optwidth / $totalstep]
set xtincr 0
set y0 0
set yt $optheight

# show result
set vrstshowx 38
set vrstshowy 237

set hrstshowx 135
set hrstshowy 143

# more info toplevel
set vmoreinfox 165
set vmoreinfoy 645

set hmoreinfox 630
set hmoreinfoy 160

# suggest text
set vsuggestx 72
set vsuggesty 225
set vsuggestheight 120

set hsuggestx 168
set hsuggesty 134
set hsuggestheight 100


set helpmessage "Thanks for using !!\nBut God helps those\nwho help themselves\n\nCopyleft noalac\nVersion 1.0.0\nFree Software"

