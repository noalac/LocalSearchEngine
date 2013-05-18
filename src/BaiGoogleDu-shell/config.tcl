# detecting OS platform
if { [regexp -nocase {windows} $tcl_platform(platform)] } {
	# on Windows
	set rottime 2000


	# show result
	set vlboxwidth 82
	set vlboxheight 9
	
	set hlboxwidth 80
	set hlboxheight 8

} elseif { [regexp -nocase {unix} $tcl_platform(platform)] } {
	# on Linux / Unix / Mac OS ...
	set rottime 1600

	# show result
	set vlboxwidth 66
	set vlboxheight 7

	set hlboxwidth 66
	set hlboxheight 6

	set vrstfont Times
	set hrstfont Times

} else {
	# default
}

# global setting
set bgwidth 680; # background width
set bgheight 355; # background height

set hbgwidth $bgwidth; # bgw for horizontal
set hbgheight $bgheight; # bgh for horizontal

# search button config
set sbtntext  BaiGoogleDu
set sbtncolor 99f

# theme options
# start up menu
set startx 0; # start up button x pos
set starty 0; # start up button y pos

# button on back
set backbgcolor #44a
set backfgcolor #fff
set backtext Click
set backx 574
set backy 0

# vertical
set vrotbtnx 160; # rotate button x pos
set vrotbtny 255; # rotate button y pos
set vsbtnx 554; # search button x pos
set vsbtny 206; # search button y pos
set vclrbtnx 355; # clear button x pos
set vclrbtny $vrotbtny; # clear button y pos
set ventx 105; # enter entry x pos
set venty 207; # enter entry y pos
set vstatlblx 0; # status label x pos
set vstatlbly 0; # status label y pos

set ventwidth 435; # enter width

# horizontal
set hrotbtnx 150
set hrotbtny 255
set hsbtnx 512
set hsbtny 193
set hclrbtnx 339
set hclrbtny $hrotbtny
set hentx 95
set henty 196
set hstatlblx 0
set hstatlbly 0

set hentwidth 410; # enter width

# basic options configure
set optwidth 240; # option block width
set optheight 42; # option block height
set vopt1x 400; # opt1 x pos
set vopt1y 69; # opt1 y pos
set vopt2x $vopt1x
set vopt2y 114
set vopt3x $vopt1x
set vopt3y 159
set animorient 1; # the orientation
# 1 means left to right
# 2 means right to left

# option background color
set r 9
set g 6
set b 3

# include option
set vincludewidth 20
set vincludelbl 408

# include all
set vinallx 490
set vinally 77

# include not
set vinnotx $vinallx
set vinnoty 122

# case sensitive
set vcasex 400
set vcasey 168

# content search
set vcontx 539
set vconty $vcasey

# option animation
set interval 20;  # opt animation interval
set totalstep 15; # between 1 ~ 15
set x0 0;              # determine which direction
set xt 0
set x0incr +[expr $optwidth / $totalstep]
set xtincr 0
set y0 0
set yt $optheight

# show result
set vrstshowx 0
set vrstshowy 22

set hrstshowx 0
set hrstshowy $vrstshowy

# more info toplevel
set vmoreinfox 610
set vmoreinfoy 0

set hmoreinfox $vmoreinfox
set hmoreinfoy 0

# suggest text
set vsuggestx 106
set vsuggesty 233
set vsuggestheight 120

set hsuggestx 95
set hsuggesty 228
set hsuggestheight 100

set helpmessage "\n\nDon't Be Evil :)\n\n"

