#!/usr/local/bin/wctksh
###############################################################
#	Usage:convert test daemon mode
#	Author:LiuZX
#	Date:2016 May
#	Version:1.0
###############################################################
set SocketPort 9900
proc Echo_Server {port} {
	global echo
	set echo(main) [socket -server EchoAccept $port]
}
proc EchoAccept {sock addr port} {
	global echo
#	puts "Accept $sock from $addr $port"
	set echo(addr,$sock) [list $addr $port]
	fconfigure $sock -buffering line
	fileevent $sock readable [list Echo $sock]
}
proc Echo {sock} {
	global echo Info Trigger
	if { [eof $sock] || [catch {gets $sock line}]} {
		close $sock
#		puts "Close $echo(addr,$sock)"
		unset echo(addr,$sock)
	} else {
		set operation [lindex [split $line] 0]
		if {[string equal "cmd" $operation]} {
			set len_line [llength $line]
			set str ""
			for {set i 1} { $i < $len_line } {incr i} {
				lappend str [lindex $line $i]
			}
			set res [eval $str]			
			puts $sock $res
		} else {
		
		}
	}
}
###############################################################
# Status Message
###############################################################
proc StatusMsg {station message} {
	global pause mode Info
#	puts $mode(abort)
#	puts $message
	if { [ string equal $message "Pause" ]  } { 
		set pause 1	
#abort lot 
		if {[string compare $mode(abort) 1]==0 } {
			evr send abortafterwafer 0
			set mode(abort) 0
		}
	}
	if { [ string equal $message "Testing" ] } {
                set pause 0
        }
#	puts $pause
}
###############################################################
# At the start of each lot DO:
#
###############################################################
proc StartOfLot {station} {
	global Info mode
	if { [file exists $Info(Ofile) ] } {
		if  [ catch { eval exec rm -f $Info(Ofile) } result ]  {
			 WriteFile $Info(LogFile) $result
		}
        	if { [file exists $Info(Tfile) ] } { } else {
                    if  [ catch { eval exec touch $Info(Tfile) } result ]  {
			 WriteFile $Info(LogFile) $result
                         tk_dialog .mess Error $result   {} defautl Ok
                    }
         	}
	}
}
############################################################
#MoveCuresor
###########################################################
proc MoveCursor {station site x y}  {
	global Info mode window pause
	if {$site == 0} {
	}
}
###############################################################
# This procedure gets called when integrator issues
###############################################################
proc InfoMessage { station message } {

	global Info  
#	WriteFile $Info(LogFile) "InfoMessage:$message"
	if [regexp {^Starting wafer session ([^ ]+)} $message match wafer] {
		set Info(WaferID) $wafer
	}
	set CURR_TIME [ clock format [ clock seconds ] -format "%Y%m%d%H%M%S" ]

	if [regexp {^Starting lot ([^ ]+)} $message match lot] {
		set Info(LotID) $lot
		if { [ regexp -nocase {^(GG|KK|C).*} $Info(LotID) match str ]  } {
			set Info(type) NOPRO
		} else {
			set Info(type) PRO
		}
	}

	if [regexp {^Reading setup ([^ ]+)} $message match setup] {
		set Info(Device) $setup
	}
	
}
###############################################################
# Get lot ID
###############################################################
#proc SetupInfo {station wsize xsize ysize xref yref flat rotation yldhi yldlo lotid} {
#	global Info
#	set Info(LotID) $lotid
#}
###############################################################
# WaferInfo:  this provides information about the current wafer
# - we used testable die
###############################################################
proc WaferInfo {station wafer_id passnumber subpass xrefoffset yrefoffset yield testable zwindow} {

	global Info  

	set Info(WaferID) "$wafer_id"
	set Info(RFile) "r_$wafer_id"
	set Info(TestableDie) $testable
	set Info(PassNumber) $passnumber

}
###############################################################
# At the end of each test (this gets called for each site) DO:
#
###############################################################
proc TestResults {station x y site test bin sort} {
	global Info mode 
	if { [ info exists Info(type) ] } { 
	} else { 
		set Info(type) Unknown
	}
	if { [ string compare $mode(eng)  1] ==0 } {
#result,site(x/y);
	    if { [ string compare $Info(type)  PRO] ==0 } {
		if { [info exists mode(1stdie) ] } {
		} else {
		     set mode(1stdie) "bin: $bin,site: $site\($x\|$y\)\;"
		}
		set mode(lastdie) "bin: $bin,site: $site\($x\|$y\)\;"
#		set mode(die)	"$mode(die) site:$site X;$x Y;$y result:$bin\n"
#		puts $Info(type) 
#		puts $mode(1stdie)
#		puts $mode(lastdie)
	    }
	}
}
##################################################
##Login
################################################
proc Login_Screen {screen} {
	global window password name Confirmed	
	set window(login) $screen
	if [winfo exists $screen] return
	
#	wm withdraw .
#	wm geometry . {}

	toplevel $screen
	wm geometry $screen "-300-400"
	wm deiconify $screen
	wm resizable $screen false false
	wm protocol $screen WM_DELETE_WINDOW { destroy $windows(login) }
	wm title $screen "TJN-FM User Authentication Screen"

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

	frame  $screen.row3
	button $screen.row3.b1 -text "Cancel" -command { 
		
	set Confirmed cancel
	destroy $window(login)
	      set name ""
              set password 
	if { [winfo exists $window(warning) ] } {
		destroy $window(warning)
	}
		.buttonMenu.debug configure -state normal
	}
	button $screen.row3.b2 -text "Confirm" -command { 
	Show_Result $window(login)
	}
	pack $screen.row3.b2 $screen.row3.b1 -side left -expand yes -fill both -padx 10 -pady 8

	focus $screen.rows.e0

	bind $screen.rows.e0 <Return> \
	{
		focus $window(login).rows.e1
	}

	bind $screen.rows.e1 <Return> \
	{
#		$window(login).row3.b2 configure -state active
#		focus $window(login).row3.b2
		$window(login).row3.b2 invoke
	}

	pack $screen.row0 $screen.rows $screen.row3 -side top
}
proc Show_Result {screen } {
	global Info button_ name password Confirmed
	# Check point to eliminate use of probe coordinator group account
	set name [ string tolower $name ]
	if { [string last $name "r42141"] == 0 || [string last $name "R42141"] == 0 } {
	} else {
		set ldap "/exec/apps/bin/ldap/ldap_auth_fsl"
		set auth_cmd "$ldap $name $password"
		if { [catch {eval exec $auth_cmd} err] } {
			
			set msg " Invalid login or password! \n\n Try Again? "
			set resp [ tk_dialog .shresult " Error " $msg warning 0 "Yes" "No" ]
		       	set name ""
                        set password ""
			if { $resp == 0 } {
				Login_Screen .login
			} else { 
			    set Confirmed cancel
			destroy $screen
			}
		} else {
			set result [eval exec $auth_cmd]
			if { [string compare $result "successful"] == 0  || \
			     [string compare $result "0:Success"] == 0   || \
                             [string compare $result "200:Valid Login"] == 0        } {
	 			if { [winfo exists $screen] != 0 } {
                         		destroy $screen
                		}	
				set Confirmed $name
				set name ""
                                set password ""
				
			} else {
                       	set msg " Invalid login or password! \n\n Try Again? "
                        set resp [ tk_dialog .shresult " Error " $msg warning 0 "Yes" "No" ]
			set name ""
                        set password ""	
                        if { $resp == 0 } {
                                Login_Screen .login
                        } else { 
				 set Confirmed cancel
				  destroy $screen

			}
			}
		}	
	}
}

############################################################
#get PC IP
##########################################################
proc get_ip { } {
	global tool Info
	set Info(PCIP) ""
	if [ file exist $Info(hostlist) ] { 
		if [ catch { set localhost [ eval exec hostname ] } err ]  {
			WriteFile $Info(LogFile) "get_ip:exec hostname ERROR. ERROR MSG: $err"	
			exit
		} else { 
                	set tool(platfrom) [string range $localhost 0 5]
                	set tool(id) [string range $localhost 6 7]
			set tool(pc_host) "$tool(platfrom)-$tool(id)"
######## need cancel #
#			set tool(pc_host) "b3j750-61"
		        	if  [ catch { set tmp [ eval exec grep $tool(pc_host) $Info(hostlist) ] } err ]   { 
					 WriteFile $Info(LogFile) "get_ip: grep $tool(pc_host) in $Info(hostlist) ERROR. ERROR MSG: $err"
					tk_dialog .mess Error "Can't get PC IP"   {} defautl Ok
					 exit
        			} else {
					set tool(pc_ip)	[lindex [split $tmp | ] 1 ]			
					regsub -all {\s}  $tool(pc_ip) "" Info(PCIP)
####### need cancel
#					set Info(PCIP) "10.192.153.143"
        			}
		}
	} else {
	WriteFile $Info(LogFile) "get_ip:No exist $Info(hostlist) ERROR. ERROR MSG: $err"
        tk_dialog .mess Error "Can't get hostlist"   {} defautl Ok
	exit
	}
}

############################
###gen socket
############################
proc socket_client { host comm } {
	global  Info connected
#	set timeout 5
#	after $timeout { set connected timeout}
	if [ catch {  
		set sock  [ socket -async $Info(PCIP) 1000 ] 
	        fconfigure $sock -buffering line
                puts $sock [ encoding convertto utf-8 $comm ]
	} err ]  {
                WriteFile $Info(LogFile) "socket_client:send command:$comm IP:$host ERROR. ERROR MSG: $err"
		return $err
        } else {
 #               fileevent $sock w { set connected ok }
  #              vwait connected
   #             if { $connected == "timeout" } {
#			return "Connected timeout"
#		} else {
#		flush $sock
        	gets $sock recive
        	return "$recive"
#		}
	}
}
################################
##check daemon status
################################
proc check_daemon { } { 
        global Info button_
        set result [socket_client $Info(PCIP) "check"]
	if { [string compare $result "eng"] ==0  } { 
#change mode to pro
		debug_command "chpro"
	} elseif { [string compare $result "pro"] ==0 } {
		set button_ $Info(toeng)
		.buttonMenu.debug configure -text $button_ -bg green -state normal
#		debug_command "chpro"
	} else { 
		set button_ "No Daemon Set"
		get_ip
		.buttonMenu.debug configure -text $button_ -bg yellow -state normal
        	tk_dialog .mess Error "Can't found Daemon_lock on windows client"   {} defautl Ok     
	}
#	puts $result
} 
############################
#warning window
############################
proc warning { warning } {
	global Info button_ window mode	 Confirmed	
	set im "/exec/apps/bin/evr/daemon_lock/warning.gif"
	set sizes [wm maxsize .]
	set x [expr {[lindex $sizes 0]/2 - 450}]
	set y [expr {[lindex $sizes 1]/2 - 135}]
	set window(warning) $warning
	if [winfo exists $warning] return
	wm withdraw .
	wm geometry . {}
	toplevel $warning
	wm geometry $warning "900x270+${x}+${y}"
	wm protocol $warning WM_DELETE_WINDOW { destroy $window(warning) }
	wm title $warning "TJN-FM Daemon_Lock Screen"
	wm iconname $warning Dialog
	wm deiconify $warning
	wm resizable $warning false false
	frame $warning.row
	set img [image create photo -file $im]
	label $warning.row.l -image $img 
	pack  $warning.row.l -side left -padx 10 -pady 8
        frame  $warning.row1
        button $warning.row1.b1 -text "Wafer" -command {
		warning_command "wafer"
       	}
        button $warning.row1.b2 -text "Lot" -command {
		warning_command "lot"
        }
        pack $warning.row1.b1 $warning.row1.b2 -side left  -padx 10 -pady 8
	pack $warning.row $warning.row1 -side top
	tkwait visibility $warning
	
}
###############################
#warning button
###############################
proc warning_command { scope } {
	global window Info Confirmed pause mode
		set mode(scope) $scope
                $window(warning).row1.b1 configure -state disabled
                $window(warning).row1.b2 configure -state disabled
                Login_Screen .login
                vwait Confirmed
#if login sucees or cancel,kill the warning window
                if { [string compare $Confirmed "fail"] !=0 || [string compare $Confirmed "cancel"] ==0 } {
                        if { [winfo exists $window(warning)] != 0 } {
                                destroy $window(warning)
                    }
                }
#if integrator not pause,wait pause
                if { [string compare $pause 1 ] !=0 } {
                                vwait pause
                }
#if login success abort lot
                if  {[ string compare $Confirmed "fail"] !=0 &&  [string compare $Confirmed "cancel"] !=0 }  {
                                debug_command "cheng"
				if {[string compare $scope "wafer"] ==0 } {	
#if entry eng mode during running lot,abortlot right now
#if enyry before runing lot,abortlot after pause
					if { [file exists $Info(Ofile)] ==0 } {
						evr send abortafterwafer 0
					} else { 
						set mode(abort) 1
					}
				}
                }
#if login sucees or canceled
                if { [string compare $Confirmed "fail"] !=0 || [string compare $Confirmed "cancel"] ==0 } {
                        if { [winfo exists $window(warning)] != 0 } {
                                destroy $window(warning)
                        }
                } else {
                        $window(warning).row1.b1 configure -state normal
                        $window(warning).row1.b2 configure -state normal
                }

}
################################################
##debug button command 
################################################
proc debug_command {status} {
	global Info button_ Confirmed mode
	if { [string equal $status  "cheng"] } { 
#			puts "cheng"
		        set result [socket_client $Info(PCIP) "cheng"]
        		if { [ string equal $result "Change mode success"]} {
			#	enter debug flag
# Tfile entry eng during runlot 
# Ofile entry eng before start of lot
				if {[string compare $Info(WaferID) ""] !=0 } {
					if { [file exists $Info(Tfile) ] } { } else {
                                        	if  [ catch { eval exec touch $Info(Tfile) } result ]  {
							WriteFile $Info(LogFile) $result
                                                	tk_dialog .mess Error $result   {} defautl Ok
							return 0
							.buttonMenu.debug configure -state normal
                                        	}
                         		}	
				} else {
			        	if { [file exists $Info(Ofile) ] } { } else {
                                        	if  [ catch { eval exec touch $Info(Ofile) } result ]  {
                                                	WriteFile $Info(LogFile) $result
                                                	tk_dialog .mess Error $result   {} defautl Ok
                                                	return 0
                                                	.buttonMenu.debug configure -state normal
                                        }
                                }

				}
                		set mode(eng) 1
#				set mode(wafer) $Info(WaferID)
				set button_ $Info(topro)
				.buttonMenu.debug configure -text $button_ -bg blue
				WriteFile $Info(LogFile) "User:$Confirmed entry EngMode,scope: $mode(scope)"
				return 1
        		} else {
                		tk_dialog .mess Error $result   {} defautl Ok
				.buttonMenu.debug configure -state normal
				return 0
        		}
	
	} elseif { [string compare $status  "chpro" ] ==0  } {
			set result [socket_client $Info(PCIP) "chpro"]
                        if { [ string equal $result "Change mode success"] } {
				if { [file exists $Info(Tfile) ] } {
	                                if { [ catch { eval exec  rm -f ${Info(Tfile)} } err ] } {
						tk_dialog .mess Error $result   {} defautl Ok
                                	}
				}
                                set mode(eng) 0
                                set button_ $Info(toeng)
                                .buttonMenu.debug configure -text $button_ -bg green -state normal
#				.buttonMenu.debug configure -state normal
				WriteFile $Info(LogFile) "System auto entry ProMode"
				return 1
                        } else {
				set result "$result,pls manually change to ProMode!"
				WriteFile $Info(LogFile) "System auto entry ProMode Error"
                                tk_dialog .mess Error $result   {} defautl Ok
				set button_ "Maually Change Pro"
				.buttonMenu.debug configure -text $button_ -bg orange  -state normal
				return 0
                        }
	} 
}
proc EndOfWafer {station wafer_id cassette slot num_pass num_tested start_time end_time lot_id} {
	global Info mode
	if { [info exists mode(1stdie) ] } {
		 WriteFile $Info(LogFile) "Under ENG Mode Test DIE:\nFisrtDie: $mode(1stdie) LastDie:$mode(lastdie)\n"	
		 unset mode(1stdie)
		 unset mode(lastdie)
	}
#	if { [ string compare $mode(wafer) "" ] ==0 && [string compare $mode(eng) 1 ] ==0 } {
#		set mode(wafer) $Info(WaferID)
#	}
}
proc EndOfLot {station} {
	global mode Info button_
	reset
}
###############################################################
#
# WriteFile
#
###############################################################
proc WriteFile { filename text } {
	global Info
	set time_stamp [clock format [clock seconds] -format "%D %T"]
	set fp [open $filename "a+"]
	puts $fp "$text Host:$Info(HOST),Part:$Info(Device) Lot:$Info(LotID) Pass:$Info(PassNumber) Wafer: $Info(WaferID)  <= @ $time_stamp"
	close $fp
}
proc reset { } { 
	global Info pause mode window
	set Info(Device) N/A
	set Info(LotID) N/A
	set Info(PassNumber) N/A
	set Info(WaferID) ""
#falg 1:pause 0:running
	set pause 1
#flag mode(eng) 0:producton mode 1:eng mode 2:risk mode  
	set mode(eng) 0
#flag 1:need abort 0:abort done
	set mode(abort) 0
#flag entry eng mode waferid
#	set mode(wafer) ""
#recored result during eng mode
	set window(warning) .warning
	set window(login) .login
        if { [winfo exists $window(login) ] } {
              destroy $window(login)
        }
        if { [winfo exists $window(warning) ] } {
              destroy $window(warning)
        }

}

evr connect localhost
evr bind endofwafer EndOfWafer
#evr bind startofwafer StartOfWafer
evr bind testresults TestResults
#evr bind setupinfo SetupInfo
evr bind infomessage InfoMessage
evr bind movecursor MoveCursor
evr bind waferinfo WaferInfo
evr bind statusmessage StatusMsg
evr bind endoflot EndOfLot
evr bind startoflot StartOfLot
set Info(home) "/exec/apps/bin/evr/daemon_lock"
set Info(HOST) [ eval exec "hostname" ]
set Info(hostlist) "/exec/apps/bin/fablots/bin/host.list"
set Info(LogFile) "/data/probe_logs/daemon_lock/daemon_lock.$Info(HOST)"
reset
get_ip
set Info(toeng) "Current Mode:Pro"
set Info(topro) "Current Mode:Eng"
#eng modetrigger file
set Info(Tfile) "/tmp/$Info(HOST)_ENG"
set Info(Ofile) "/tmp/$Info(HOST)_ENG_tmp"
set button_ $Info(toeng)
if {[file exists $Info(Tfile)]} {
       if { [ catch { eval exec  rm -f ${Info(Tfile)} } err ] } {
                 tk_dialog .mess Error $result   {} defautl Ok
       }

}
if {[file exists $Info(Ofile)]} {
       if { [ catch { eval exec  rm -f ${Info(Ofile)} } err ] } {
                 tk_dialog .mess Error $result   {} defautl Ok
       }

}
if [catch { Echo_Server $SocketPort } err ] { 
	puts "Failed startup Socket Daemon, Error: $err"
	exit 99
} else {
	puts "Success in startup Daemon	"
}
wm overrideredirect . true
set sizes [wm maxsize .]
set size(x) [expr {[lindex $sizes 0]/2 - 175}]
set size(y) [expr {[lindex $sizes 1]/2 - 70}]
wm geometry . "350x140+${size(x)}+${size(y)}"
label .l -bg green -fg black -bd 10 -relief raised -text " TJNPRB Daemon Lock \n\n @ Copyright 2015 NXP Semiconductor, Inc.\n\n"
pack .l -expand yes -fill both
after 4000 {
	destroy .l
	wm withdraw .	
	wm geometry . {}
	toplevel .buttonMenu
	wm overrideredirect .buttonMenu true
	label .buttonMenu.l -bg #9478FF -fg white -text "Daemon Lock"
	button .buttonMenu.debug -text $button_ -bg green -fg black -command {
#		puts $pause
		#if entry debugmode
		.buttonMenu.debug configure -state disabled
		if { [string compare $pause 1 ] !=0 } {
			evr send pause 0
		}
		if { [ string  compare $button_ ${Info(toeng)} ] ==0 } {
			if { [string compare $pause 1 ] !=0 } {
				vwait pause
			}
			 	if [winfo exists $window(warning)] return
			 	warning $window(warning)
		} elseif { [ string  compare $button_ ${Info(topro)} ] ==0 } {
			.buttonMenu.debug configure -state disabled
			debug_command "chpro"
		} else { 
			check_daemon
		}
	}
	pack .buttonMenu.l .buttonMenu.debug -side top -expand yes -fill both
	wm geometry .buttonMenu "-0-200"
	wm deiconify .buttonMenu 
	# update the StationOwner
	check_daemon
}
