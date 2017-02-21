
proc TIME_STAMPd {} {
# Example: Wed May 20 07:09:34 2009
	return [clock format [clock seconds] -format "%c" -gmt 0]
}
proc TIME_STAMPf {} {
# Example: 20090520-070930
#Problem with Y wrapped with % signs
	set a [clock format [clock seconds] -format "%y%m%d-%H" -gmt 0]
	set b [clock format [clock seconds] -format "%M" -gmt 0]
	set c [clock format [clock seconds] -format "%S" -gmt 0]
	set d "${a}${b}${c}"
#Need to hardcode 20, because %Y followed by %m will be converted by SCCS
	return "20$d"
}
proc TIME_STAMPm {} {
# Example: 200905
#Problem with Y wrapped with % signs
	set a [clock format [clock seconds] -format "%y%m" -gmt 0]
#Need to hardcode 20, because %Y followed by %m will be converted by SCCS
	return "20$a"
}
proc TIME_STAMPs {} {
# Example: 1242828567
	return [clock seconds]
}
proc TIME_STAMPt {} {
# Example: 05/20/09 07:09:38
	return [clock format [clock seconds] -format "%D %T" -gmt 0]
}


proc TestResults {station x y site testnumber bin sort} {
	global wafer pass Info stop_flag
	incr Info(Tested)
	incr Info(toleration)
#	puts "toleration = $Info(toleration)"
#	puts "testresults: stop_flag is $stop_flag toleration = $Info(toleration)"
	if { $stop_flag == 1} {
#		puts "stop_flag is $stop_flag pause integrator! toleration = $Info(toleration)"
		evr send pause -alarm 0
		if {$Info(toleration) > 5} {
#			puts "toleration $Info(toleration) over 5, show window"
			ShowWindow
		}
		
	}
	
}

proc Login_Screen {screen} {

	global Confirmed name password Info drawboard ErrorComments

	set name ""
	set password ""
	
	if [winfo exists $screen] return
	
	set drawboard $screen


#	wm withdraw .
	wm geometry . {}

	toplevel $screen
	wm geometry $screen "-300-400"
	wm deiconify $screen
	wm resizable $screen false false
	wm protocol $screen WM_DELETE_WINDOW { destroy $screen }
	wm title $screen "TJN-FM User Authentication Screen"
	wm protocol $screen WM_DELETE_WINDOW "Login_Screen $screen "

	tkwait visibility $screen
	focus -force $screen
	#grab set -global $screen

	frame $screen.row0
	label $screen.row0.l -text " Plese Enter Your OneIT Password "
	pack  $screen.row0.l -side right -padx 10 -pady 8

	frame $screen.rows
	label $screen.rows.l0 -text "Login:" -anchor e
	entry $screen.rows.e0 -textvariable name -width 15
	grid  $screen.rows.l0 $screen.rows.e0 -padx 6 -pady 4

	label $screen.rows.l1 -text "Password:" -anchor e
	entry $screen.rows.e1 -textvariable password -width 15 -show *
	grid  $screen.rows.l1 $screen.rows.e1 -padx 6 -pady 4

#	label $screen.rows.l1 -text "Password:" -anchor e
	if { [string compare $screen ".outofrange"] == 0 } {
#		puts "screen = $screen, add new line"
		label $screen.rows.l2 -text "Comments:" -anchor e
		entry $screen.rows.e2 -textvariable ErrorComments -width 30 
		grid $screen.rows.l2 $screen.rows.e2 -padx 6 -pady 4
	} 
#	puts "Debug: $screen,"
#	grid  $screen.rows.l1 $screen.rows.e1 -padx 6 -pady 4

	frame  $screen.row3
	#button $screen.row3.b1 -text "Cancel" -command { destroy $screen }
	button $screen.row3.b2 -text "Confirm" -command { Show_Result $drawboard}
	
#	if { [string compare $screen ".input"] } {
	pack $screen.row3.b2 -side left -expand yes -fill both -padx 10 -pady 8
#	} elseif { [string compare $screen ".outofrange"] } {
#		pack $screen.row3.b2 -side left -expand yes -fill both -padx 10 -pady 8
#	}
	
	
	focus $screen.rows.e0

	bind $screen.rows.e0 <Return> \
	{
		focus $screen.rows.e1
	}

	bind $screen.rows.e1 <Return> \
	{
		$screen.row3.b2 configure -state active
		focus $screen.row3.b2
	}

	bind $screen.row3.b2 <Return> { Show_Result $drawboard}
	pack $screen.row0 $screen.rows $screen.row3 -side top
	
	set Info($screen) 1
	AutoRaise $screen
}

proc Show_Result {screen} {
	global name password Confirmed Info verify_passwd_prog
	
	set Info($screen) 0
	
	if { [winfo exists $screen] != 0 } {
		destroy $screen
	}

	if { [string last $name "r42141"] == 0 || [string last $name "R42141"] == 0 } {
		set msg " Invalid login name! \n\n"
		set resp [ tk_dialog .shresult " Error " $msg warning 0 "Try Again" ]
		set Confirmed($screen) failed
#		if { $resp == 0 } {
#			set name ""
#			set password ""
#			Login_Screen $screen
#		} 
	} else {
		set auth_cmd "$verify_passwd_prog $name $password"
		if { [catch { set result [ eval exec $auth_cmd ] } err] } {
			set msg " Invalid login or password! \n\n Try Again? "
			set resp [ tk_dialog .shresult " Error " $msg warning 0 "OK" ]
			set Confirmed($screen) failed
#			if { $resp == 0 } {
#				set name ""
#				set password ""
#				Login_Screen $screen
#			} 
		} else {
			#set result [eval exec $auth_cmd]
			if { [string compare $result "successful"] == 0  || \
				 [string compare $result "0:Success"] == 0   || \
				 [string compare $result "200:Valid Login"] == 0        } {
				set Confirmed($screen) $name
			} else {
				set msg " Invalid login or password! \n\n Try Again? "
				set resp [ tk_dialog .shresult " Error " $msg warning 0 "OK" ]
				set Confirmed($screen) failed

#				if { $resp == 0 } {
#					set name ""
#					set password ""
#					Login_Screen $screen
#				} 
			}
		}
	}
}

proc WriteLog {filename text} {
	set time_stamp [TIME_STAMPd]
	set fp [open $filename "a+"]
	puts $fp "$text <= Record at $time_stamp"
	close $fp
}

proc AutoRaise {dialog} {
	global Info
	if { [ winfo exists $dialog ] && $Info($dialog) == 1 } {
		raise $dialog
		after 5000 AutoRaise $dialog
	}
}

proc ShowWindow {} {
#	puts "ShowWindow executed!!"
	global Temperature_input Info Confirmed LogFile stop_flag BinDir
	set Info(toleration) 0
	
	if {[winfo exists .tempinput]} {
#		puts "raise .tempinput, return"
		raise .tempinput
		return
	}
#	puts ".tempinput did not exists,ShowWindow"
	
	set Temperature_input [Dialog_Prompt "Please enter the current temperature on Prober!!"]
	if { [ string compare $Temperature_input "" ] == 0 } {	
		tk_dialog .warning "Temperature input check" "Please input right numbers" warning 0 "OK"
		ShowWindow
	} elseif { ! [regexp {^(\-)?[0-9]+(\.)?[0-9]+$} $Temperature_input] } {
		tk_dialog .warning "Temperature input check" "Please input right numbers" warning 0 "OK"
		ShowWindow
	} else {
		set lower_limit [ expr $Info(HOTP:${Info(pass)}) - $Info(HCBS:${Info(pass)})]
		set higher_limit [ expr $Info(HOTP:${Info(pass)}) + $Info(HCBS:${Info(pass)})]
		
		if { $Temperature_input > $higher_limit || $Temperature_input < $lower_limit } {
			set resp [ tk_dialog .warning "Temperature input check" "Input Temperature is $Temperature_input, are you sure?" warning 0 "YES" "No" ]
#			set resp [ tk_dialog .warning "Temperature input check" "$BinDir/MakeSure.gif" warning 0 "YES" "No" ]
			if { $resp == 0 } {
#				destroy .warning
				RaiseError "Input Temperature is Out of Range!!"
			} else {
#				puts "show window again $resp"
				ShowWindow
			}
		} else {
			set Confirmed(.input) ""
			Login_Screen .input
			vwait Confirmed(.input) 
			if { [ string compare $Confirmed(.input) "failed" ] != 0} {
				set stop_flag 0
#				puts "stop_flag release!!! user is $Confirmed(.input)"
				WriteLog $LogFile "User $Confirmed(.input) input $Temperature_input, between $lower_limit and $higher_limit => verify pass! release lock!!"
			} else {
				tk_dialog .warning "Temperature Input check" "login failed! please login again" warning 0 "OK"
				ShowWindow
			}
		}
	}	
}

proc RaiseError {str} {
	global Info Confirmed BinDir stop_flag ErrorComments
	set Info(ErrorStr) $str
	set map "$BinDir/OutOfRangeWarning.gif"
#	wm withdraw .
	toplevel .outofrange
	wm title .outofrange OutOfRangeWarningAlarm 
	wm iconname .outofrange Dialog
	frame .outofrange.top -relief raised -bd 1
	pack .outofrange.top -side top -fill both
	frame .outofrange.bot -relief raised -bd 1
	pack .outofrange.bot -side bottom -fill both
	set im [image create photo -file $map]
	label .outofrange.top.image -image $im
	pack .outofrange.top.image -side left -padx 5m -pady 5m
	button .outofrange.bot.button -text OK -command {
		set Info(.outofrange) 0
		destroy .outofrange
		set Confirmed(.outofrange) ""
		Login_Screen .outofrange
		vwait Confirmed(.outofrange)
		if { [ string compare $Confirmed(.outofrange) "failed" ] != 0} {
			set stop_flag 0
			WriteLog $LogFile "User $Confirmed(.outofrange) Check OutOfRange Issue! Comments: \"$ErrorComments\""
		} else {
			tk_dialog .warning "Temperature input check" "login failed! please login again" warning 0 "OK"
			RaiseError $Info(ErrorStr)
		}	
	}
	pack .outofrange.bot.button -side left -expand 1 \
	-padx 5m -pady 5m -ipadx 2m -ipady 1m
	tkwait visibility .outofrange.bot
	focus -force .outofrange.bot.button
	grab set -global .outofrange
	set Info(.outofrange) 1
	AutoRaise .outofrange
}

proc InfoMsg {station message } {
	global wafer pass Info stop_flag
	
}

########################################################
#	get setup file location and name, then read it,
#	3 parameters: 	1. enable hot chuck.
#					2. hot chuck temperature.
#					3. temperature range.
########################################################

proc SetupName {station floordir setupfile} {
#	puts "SetupName triggered!!!"
	global Info BinDir
	set Info(Path) $floordir
	set Info(Device) $setupfile
	set Path [ string trimright $floordir 1 ]
	
	set setup_file "$Path/$Info(Device)"
# maximum pass is 8 in current navigator 
	for {set i 1} {$i < 8} {incr i} {

# HOTP stands for hot chuck set temperature in navigator.
		set cmd "$BinDir/getVal $setup_file HOTP${i}"
		if { [catch {set Temp [eval exec "$cmd"]} err] } {
			puts "error when execute command : $cmd"
#			error when execute command : $cmd
		} else {
			if { [string compare $Temp ""] != 0 } {
				set Info(HOTP:${i}) $Temp
#				puts "setting Info(HOTP:${i}) to $Temp"
			}
		}

# HCE means the enable hot chuck in navigator, 1 stands for yes, 0 stands for no.		
		set cmd "$BinDir/getVal $setup_file HCE${i}"
		if { [catch {set HotFlag [eval exec "$cmd"]} err] } {
			puts "error when execute command : $cmd"
#			error when execute command : $cmd
		} else {
			if { [string compare $HotFlag ""] != 0 } {
				set Info(HCE:${i}) $HotFlag
#				puts "setting Info(HCE:${i}) to $HotFlag"
			}
		}

# HCBS means temperature range in navigator		
		set cmd "$BinDir/getVal $setup_file HCBS${i}"
		if { [catch {set Range [eval exec "$cmd"]} err] } {
			puts "error when execute command : $cmd"
#			error when execute command : $cmd
		} else {
			if { [string compare $Range ""] != 0 } {
				set Info(HCBS:${i}) $Range
#				puts "setting Info(HCBS:${i}) to $Range"
			}
		}
		
	}
}

proc SetupInfo {station wsize xsize ysize xref yref flat orientation yldhi yldlo lotid } {
	global Info
	set Info(LotID) [string toupper $lotid]
}

########################################################
#	get pass info
#
########################################################

proc WaferInfo {station wafer_id passnumber subpass xrefoffset yrefoffset yield testable zwindow} {

#	puts "WaferInfo: triggered"
	global wafer pass Info stop_flag BinDir 
	set wafer $wafer_id
	set pass $passnumber
	set Info(pass) $pass

#	if { $Info(HCE:${pass}) == 1 && $Info(HOTP:${pass}) != "" } {
#		set stop_flag 1
#	}
	
}

#########################################################
#
#	By pass calculate if it meets requirement. 
#set stop_flag to 1 if meets.
#########################################################

proc StartOfLot {station} {
	global Info stop_flag
#	puts "StartOfLot: HCE: $Info(HCE:${Info(pass)}) HOTP: $Info(HOTP:${Info(pass)}) "
	if { $Info(HCE:${Info(pass)}) == 1 && $Info(HOTP:${Info(pass)}) != "" } {
#		puts "setting stop_flag to 1 "
		set stop_flag 1
	}
}

#################################################
#	Trigger ResetAll data while EndOfLot
#################################################

proc EndOfLot {station} {
	ResetAll
}

#################################################
#	Reset Function for every lot.
#################################################

proc ResetAll {} {
	global wafer pass Info stop_flag BinDir Temperature_input
	set wafer 0
	set pass 0
	set stop_flag 0
	set Info(Tested) 0
	set Info(Device) ""
	set Info(LotID) ""
	set Info(toleration) 100
	set Temperature_input ""
# max 8 pass in current navigator.
	for {set i 1} {$i < 8} {incr i} {
		set Info(HCE:${i}) ""
		set Info(HOTP:${i}) ""
		set Info(HCBS:${i}) ""
	}
}


###############################################################
#
#	Lib proc.
#
###############################################################

proc Dialog_Create { top title args} {
	global dialog
	if [ winfo exists $top ] {
		switch -- [wm state $top] {
			normal {
				raise $top
			}
			withdrawn -
			iconic {
				wm deiconify $top
				catch {wm geometry $top $dialog(geo,$top)}
			}
		}
		return 0
	} else {
		eval {toplevel $top} $args
		wm title $top $title
		return 1
	}
}

proc Dialog_Wait {top varName {focus {}}} {
	upvar $varName var
	bind $top <Destroy> [ list set $varName cancel]
	if {[string length $focus] == 0} {
		set focus $top
	}
	set old [focus -displayof $top]
	focus $focus
	catch {tkwait visibility $top}
	catch {grab $top}
	tkwait variable $varName
	catch {grab release $top}
	focus $old
}

proc Dialog_Prompt { str } {
	global prompt
	
	set prompt(result) ""
	
	set f .tempinput
	if [Dialog_Create $f "Enter Prober Temperature" -borderwidth 10 ] {
		message $f.msg -text $str -aspect 1000
		entry $f.entry -textvariable prompt(result)
		set b [frame $f.buttons]
		pack $f.msg $f.entry $f.buttons -side top -fill x
		pack $f.entry -padx 5
		button $b.ok -text OK -command { set prompt(ok) 1 }
		button $b.cancel -text Cancel -command { set prompt(ok) 0 }
		pack $b.ok -side left
		pack $b.cancel -side right
		bind $f.entry <Return> {set prompt(ok) 1 ; break}
		bind $f.entry <Control-c> {set prompt(ok) 0 ; break }
		
		wm protocol $f WM_DELETE_WINDOW { destroy $f }
		wm title $f "Enter Prober Temperature"
		wm protocol $f WM_DELETE_WINDOW "Dialog_Prompt \"$str\" "
		wm geometry $f "600x280+0+0"
		
	}
	set prompt(ok) 0
#	Dialog_Wait $f prompt(ok) $f.entry
	vwait prompt(ok)
	if {$prompt(ok)} {
		destroy .tempinput
		return $prompt(result)
	} else {
		destroy .tempinput
		Dialog_Prompt $str
		return {}
	}
}

#######################################################
#
#	Main Program
#
#######################################################

wm withdraw .
global wafer pass Info stop_flag BinDir Temperature_input verify_passwd_prog Confirmed name password LogFile
set BinDir "/exec/apps/bin/evr/QueryTemp"
set verify_passwd_prog "/exec/apps/bin/ldap/ldap_auth_fsl"
#set Confirmed failed
set name ""
set password ""
set Info(HOST) [eval exec "hostname"]
set LogFile "/data/probe_logs/TempCheck/$Info(HOST).log"
#set setup_location "/floor/data/setups"

ResetAll 


evr connect localhost
evr bind testresults TestResults
evr bind infomessage InfoMsg
evr bind waferinfo WaferInfo
evr bind setupname SetupName	
evr bind endoflot EndOfLot
evr bind setupinfo SetupInfo
evr bind startoflot StartOfLot
