#!/usr/local/bin/wctksh_3.2

###############################################################
#Function:check and write OCR
#
#Author:LiuZX
#Data:2016-08-09
###############################################################





###############################################################
# Status Message
###############################################################
proc StatusMsg { station message } {
        global pause Info
#       puts $mode(abort)
#       puts $message
        if { [ string equal $message "Pause" ]  } {
                set pause 1
        }
        if { [ string equal $message "Testing" ] } {
                set pause 0
        }
#       puts $pause
}
##############################################################
#check if open OCR in navigator
#############################################################
proc WaferInfo {station wafer_id passnumber subpass xrefoffset yrefoffset yield testable zwindow} {
	global Info conf
	set Info(PassNumber) $passnumber
	set conf(ocr) [ lindex [ split $conf(ocr_list) \n ] 0 ]
	if {[string compare $Info(debug) 1]==0} {
		puts "WaferInfo--conf(ocr)(masterpass):$conf(ocr)"
	}
	if { [string compare $conf(ocr) 1 ] !=0 } {
		set conf(ocr) [ lindex $conf(ocr_list) $Info(PassNumber)]
	}
	if {[string compare $Info(debug) 1]==0} {
		puts "WaferInfo--conf(ocr)(subpass):$conf(ocr)"
	}
}
###############################################################
# This procedure gets called when integrator issues
###############################################################
proc InfoMessage { station message } {
        global Info
#       WriteFile $Info(LogFile) "InfoMessage:$message"
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
# At the start of each lot DO:
#query promis_list
###############################################################
proc StartOfLot {station} {
        global Info BinDir conf
		if  { [ string compare $Info(type) PRO ]==0 } {
        		if { [ string compare $conf(ocr) 1 ]==0 } {
#				set cmd "$BinDir/etc/promis_list NE31561.1J"
				set cmd "$BinDir/etc/promis_list $Info(LotID)"
				if { [ catch { set result [ eval exec "$cmd " ] } err ] } { 
					tk_dialog .shresult " Error " $err warning 0 "Ok"
				} else { 
					set Info(promis_list) [ split $result , ]
				}
			}
	}
}
##########################################################
#check if physical wafer in promis wafer list:abandon-20160809
##########################################################
proc StartOfWafer { station } {
	global Info window BinDir conf
	if  { [ string compare $Info(type) PRO ]==0 } {
        	if { [ string compare $conf(ocr) 1 ]==0 } {
			if { [ regexp {1-(\d+)} $Info(WaferID) match wafer ] } {
				foreach id $Info(promis_list)  {
#					puts "|$id| <-> |$wafer|"
					if { [string compare $id $wafer ] == 0 } {
						return 
					}
				}
				set err "waferid:$Info(WaferID) doesn't match promis list:$Info(promis_list)"
				WriteFile $Info(LogFile) $err
				set window(img) "$BinDir/etc/warning_promis.gif"
				set Info(ocrnomatch) 1
			} else {
				set err "Can't recognize waferid:$Info(WaferID)"
		 		tk_dialog .shresult " Error " $err warning 0 "Ok"
				WriteFile $Info(LogFile) $err
			}
		}
	}
}
############################################################
#MoveCuresor
#ensure the warning window is response correctly
###########################################################
proc MoveCursor {station site x y}  {
        global Info window pause
        if {$site == 0} {
		if { [string compare $window(show) 1 ] == 0 } {
		 if { [winfo exists $window(warning)] != 0 } { 
			if {[string compare $Info(debug) 1]==0} {
				puts "MoveCursor--pause:$pause"
			}
                 	if { [string compare $pause 0 ] ==0 } {
                      		evr send pause $station
                	}
			wm deiconify $window(warning)
		 } else { 
			warning $window(warning) $window(img)
			}
		 }
        }
}
##########################################################
#prober doesn't support this function,abandon-20160809
#########################################################
proc cassetteinfo { station cassStat } {
	global Info conf
#	if {[ string compare $conf(ocr) 1 ]==0 } {
		puts $cassStat	
#	}
}
########################################################
#get prober OCR and compare with integrator message
#######################################################
proc waferpassinfo { station block } {
	global conf Info BinDir pause window Confirmed
	if  { [ string compare $Info(type) PRO ]==0 } {
	if { [ string compare $conf(ocr) 1 ]==0 } {
#get OCR and slot  Info
		set tmpfile "/tmp/smwaferpassinfo\.$Info(LotID)"
		if { [catch { set fh [open $tmpfile "w"]} err ] } {
			WriteFile $Info(LogFile) "waferpassinfo:Error creating temp file $tmpfile : $open_err"
			 tk_dialog .shresult " Error " $err warning 0 "Ok"
                	return
		}
		puts $fh $block
        	close $fh
		if { [catch { set fh [open $tmpfile "r"] } err ] } {
                	WriteFile $Info(LogFile) "waferpassinfo: Error reading temp file $tmpfile : $open_err"
			tk_dialog .shresult " Error " $err warning 0 "Ok"
                	return
        	}
        	inf infcmd
        	infcmd load $fh
        	close $fh		
		if  {[ file exists $tmpfile ] } {
			file delete $tmpfile
		}	
        	if { [set wpi [infcmd blocks -noerror smwaferpassinfo]] == {}} {
                	set Info(OCR)  {}
        	} else {
			set Info(OCR) [$wpi data -noerror OCR]
                        set Info(slot) [$wpi data -noerror SLOT]
                }
#check if physical wafer in promis wafer list
		set match_promis 0
                foreach id $Info(promis_list)  {
			if {[string compare $Info(debug) 1]==0} {
                        	puts "waferpassinfo--promis_list compare:|$id| <-> |$Info(slot)|"
			}
                        if { [string compare $id $Info(slot) ] == 0 } {
				set match_promis 1
				break
                        }
                }
		if {[string compare $match_promis 1]!=0} {
                	set err "waferid:$Info(WaferID) doesn't match promis list:$Info(promis_list)"
                	WriteFile $Info(LogFile) $err
                	set window(img) "$BinDir/etc/warning_promis.gif"
                	set Info(ocrnomatch) 0
		}
#compare with calculate resulte
		set cmd "$BinDir/etc/ocr_compare.pl $Info(Device) $Info(LotID) $Info(slot)"
#		set cmd "$BinDir/etc/ocr_compare.pl WA04M77B TM48999.1W 5"
		if { [catch { set Info(OCR_cal) [ eval "exec $cmd" ] } errmsg]} {
                        set err "OCR compare Error: $errmsg"
			tk_dialog .shresult " Error " $err warning 0 "Ok"
                        WriteFile $Info(LogFile) $err
                        return
		}
		if  { [ string compare $Info(OCR_cal) $Info(OCR) ]!=0 } {
#convertor vendor id to lotid+waferid
#			set cmd "$BinDir/etc/diamond_list PWBABY0Q101A5";
			set cmd "$BinDir/etc/diamond_list $Info(OCR)";
                	if { [catch { set lotinfo [ eval "exec $cmd" ] } errmsg]} {
                        	set err "OCR compare Error: $errmsg"
                        	tk_dialog .shresult " Error " $err warning 0 "Ok"
                        	WriteFile $Info(LogFile) $err
                        	return
                	} else {
				if [regexp {(.*)\.\w{2,4}} $Info(LotID) match lotinfo_short] {
					append lotinfo_short "-$Info(slot)"
				        if {[string compare $Info(debug) 1]==0} {
                                        	puts "waferpassinfo--Vendor2Inhouse_scribe:$lotinfo,lotinfo_short:$lotinfo_short"
                                	}
					if  { [ string compare $lotinfo $lotinfo_short ]!=0 } {
		                        	WriteFile $Info(LogFile) "OCR doesn't match OCR_rd:$Info(OCR) Lotinfo:$lotinfo"
                        			set window(img) "$BinDir/etc/warnning.gif"
						set Info(ocrnomatch) 1
					}
				} else {
					set err "Unknow LotID:$Info(LotID)"
					WriteFile $Info(LogFile) $err
					tk_dialog .shresult " Error " $err warning 0 "Ok"
				}
			}	
		}
                if {[string compare $Info(debug) 1]==0} {
                        puts "waferpassinfo--OCR:$Info(OCR) OCR_cal:$Info(OCR_cal)"
                }

		if { [string compare $Info(ocrnomatch) 1]==0 } {
			evr send  pause $station
			warning $window(warning) $window(img)
			return
			
		}
		write_ocr $Info(OCR)	
	}
	}
}
proc write_ocr { ocr } {
	global Info conf 
                set filename [file join $Info(floor) $Info(Device) $Info(LotID) .ocr r_$Info(WaferID)]
                set cmd "$conf(OCR_WRITE) \"$Info(Device)\" \"$Info(LotID)\" \"r_$Info(WaferID)\" \"$ocr\""
                if { [catch { eval "exec $cmd"} errmsg]} {
                        set err "OCR Error: $errmsg,OCR:r_$Info(WaferID)"
                        tk_dialog .shresult " Error " $err warning 0 "Ok"
                        WriteFile $Info(LogFile) $err
                        return
                }
                if {! [file readable $filename]} {
                        set err "OCR Error: missing file: $filename"
                        tk_dialog .shresult " Error " $err warning 0 "Ok"
                        WriteFile $Info(LogFile) $err
                        return
                }
                if { [catch {set fd [open $filename r]} err]} {
                        set err "OCR Error: could not open OCR file: $err"
                        tk_dialog .shresult " Error " $err warning 0 "Ok"
                        WriteFile $Info(LogFile) $err
                        return
                }
                set ocrstr [gets $fd]
                close $fd
                if {$ocrstr != $ocr} {
                        set err "OCR Error: bad file content, $ocrstr != $ocr, in $filename"
                        WriteFile $Info(LogFile) $err
                        tk_dialog .shresult " Error " $err warning 0 "Ok"
                        return
                }

                WriteFile $Info(LogFile) "waferpassinfo:OCR:$ocr write done"
}
proc SetupName { station floordir setupfile } {
	global conf Info BinDir 
#	puts "setup"
	set Path [ string trimright $floordir 1 ]
	set cmd "$BinDir/etc/getVal $Path/$setupfile IDEN"
	if { [catch { set conf(ocr_list) [eval exec $cmd]} err] } {
		WriteFile $Info(LogFile) "SetupName:read setupfile ERROR. ERROR MSG: $err"	
		return
	} 
}
###############################################################
#
#reset OCR
###############################################################
proc EndOfWafer {station wafer_id cassette slot num_pass num_tested start_time end_time lot_id} {
	global Info
	set Info(OCR) N/A	
	set Info(ocrnomatch) 0
}
##############################################################
#
#reset variable
#############################################################
proc EndOfLot {station} {
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
        if { [ catch { set fp [open $filename "a+"] } err ] } { 
		 tk_dialog .shresult " Error " $err warning 0 "Ok"
	} else {
        	puts $fp "$text Host:$Info(HOST),Part:$Info(Device) Lot:$Info(LotID) Pass:$Info(PassNumber) Wafer: $Info(WaferID)  <= @ $time_stamp"
        	close $fp
	}
}
#############################################################
# reset
#
#############################################################
proc reset { } {
	global Info window pause
        set Info(Device) N/A
        set Info(LotID) N/A
        set Info(PassNumber) N/A
        set Info(WaferID) N/A
	set Info(OCR) N/A
	set Info(ocrnomatch) 0
	set window(warning) .win_warning
	set window(show) 0
#falg 1:pause 0:running
        set pause 1
	
}
######################################################
#warning window
#
#####################################################
proc warning { warning im } {
        global Info  window BinDir  Confirmed pause 
	set window(show) 1
        set sizes [wm maxsize .]
        set x [expr {[lindex $sizes 0]/2 - 450}]
        set y [expr {[lindex $sizes 1]/2 - 135}]
        set window(warning) $warning
        if [winfo exists $warning] return
        wm withdraw . 
        wm geometry . {}
        toplevel $warning
        wm geometry $warning "800x200+${x}+${y}"
        wm protocol $warning WM_DELETE_WINDOW { destroy $window(warning) }
        wm title $warning "TJN-FM OCR Warnning"
        wm iconname $warning Dialog
        wm deiconify $warning 
        wm resizable $warning false false
        frame $warning.row
        set img [image create photo -file $im]
        label $warning.row.l -image $img 
        pack  $warning.row.l -side left -padx 10 -pady 8
	frame $warning.row2 
	label $warning.row2.ocr -text OCR:$Info(OCR)
	label $warning.row2.device -text DEVICE:$Info(Device)
	label $warning.row2.lot -text LOT:$Info(LotID)
	label $warning.row2.wafer -text WaferID:$Info(WaferID)
	pack $warning.row2.ocr  $warning.row2.device  $warning.row2.lot $warning.row2.wafer -side left  -padx 10 -pady 8
        frame  $warning.row1
        button $warning.row1.b1 -text "Abort Lot" -command {
		warning_command abortlot
        }
        button $warning.row1.b2 -text "Contiune Lot" -command {
                	set msg "OCR doesn't match.\nSubstrate id will be calculated base on Lot and Waferid Info from integraor.\n\nDo you want to contiune without check? "
                	set resp [ tk_dialog .shresult " Warnning " $msg warning 0 "Yes" "No" ]
                	if { $resp == 0 } {
				warning_command start
                	}
        }
        pack $warning.row1.b1 $warning.row1.b2 -side left  -padx 10 -pady 8
        pack $warning.row $warning.row2 $warning.row1 -side top
        tkwait visibility $warning
 
}
##################################################
##Login window
#
################################################
proc Login_Screen {screen opt } {
        global window password name Confirmed BinDir
        set window(login) $screen
	set window(opt) $opt
        if [winfo exists $screen] return

#       wm withdraw .
#       wm geometry . {}
        toplevel $screen
        wm geometry $screen "-200-300"
        wm deiconify $screen
        wm resizable $screen false false
        wm protocol $screen WM_DELETE_WINDOW { destroy $window(login) }
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
	}
        button $screen.row3.b2 -text "Confirm" -command {
		if { [string compare $window(opt) start ]==0 } {
                if { [catch { set fh [open $conf(permission) "r"]} err ] } {
                       set err "Can't open permission list"
                        tk_dialog .shresult " Error " $err warning 0 "Ok"
                        return
                }
                set permission 0
                while { [gets $fh line] >= 0} {
                        if [regexp {^(super|J750_owner):(.*)} $line match groupt user] {
                                 set user_list [ split $user , ]
                                        foreach id $user_list  {
                                                if { [string equal -nocase $name  $id ] == 1 } {
                                                        set permission 1
                                                        break
                                                }
                                }

                        }
			if {[string compare $permission 1] ==0} {
				break
			}
                }
                close $fh
                if { $permission == 0} {
                        set msg "Permission deneed.\n\nOnly process and super can contiune "
                        set resp [ tk_dialog .shresult " Warnning " $msg warning 0 "Ok" ]
                        return
                }
		}
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
#               $window(login).row3.b2 configure -state active
#               focus $window(login).row3.b2
                $window(login).row3.b2 invoke
        }

        pack $screen.row0 $screen.rows $screen.row3 -side top
}
################################################################
#check LDAP result
#
#################################################################
proc Show_Result { screen } {
	global Info  name password Confirmed BinDir conf window
        set ldap "$BinDir/etc/login"
        set cmd "$ldap $name $password"
        if { [catch { set result [ eval exec $cmd ] } err] } {
		tk_dialog .shresult " Error " $err warning 0 "Ok"
        } else {
		if { [string compare $result 1 ]==0 } {
	        	if { [winfo exists $screen] != 0 } {
                                    destroy $screen
                        }
			set window(show) 0
                        set Confirmed $name
                        set name ""
                        set password ""
		} else { 
                        set msg " Invalid login or password! \n\n Try Again? "
                        set resp [ tk_dialog .shresult " Error " $msg warning 0 "Yes" "No" ]
                        set password ""
                        if { $resp == 0 } {
                        } else {
                                set Confirmed cancel
				destroy $screen
                        }

		}
        }
}
###############################
#warning button
###############################
proc warning_command { opt } {
        global window Info Confirmed pause 
	Login_Screen .login $opt	
#wait user login confirmed
	vwait Confirmed
	if {[string compare $Info(debug) 1]==0} {
		puts "warning_command--Confirmed:$Confirmed"
	}	
        if { [string compare $Confirmed "fail"] !=0 && [string compare $Confirmed "cancel"] !=0 } {
                 if { [winfo exists $window(warning)] != 0 } {
                             destroy $window(warning)
                 }
		 WriteFile $Info(LogFile) "$Confirmed $opt"
#	write the probe read OCR
		 if { [string compare $opt start]==0 } {
		 	write_ocr $Info(OCR)
		 }
                 if { [string compare $pause 1 ] !=0 } {
                             vwait pause
                 }
		 evr send $opt 0
		 if { [string compare $opt abortlot ]==0 } {
			     evr send start 0
		 }
        }
}
evr connect localhost
evr bind infomessage InfoMessage
evr bind startoflot StartOfLot
evr bind statusmessage StatusMsg
evr bind setupname SetupName
evr bind movecursor MoveCursor
evr bind waferpassinfo   waferpassinfo
evr bind endofwafer EndOfWafer
evr bind waferinfo WaferInfo
evr bind endoflot EndOfLot
#evr bind startofwafer StartOfWafer
set BinDir "/exec/apps/bin/evr/OCR"
set Info(HOST) [ eval exec "hostname" ]
set Info(floor) "/floor/data/results_map"
set Info(LogFile) "/data/probe_logs/OCR/OCR.$Info(HOST)"
set Info(HOST) [ eval exec "hostname" ]
set conf(OCR_WRITE) [file join $BinDir etc ocr_write.sh]
set conf(permission) "/exec/apps/bin/evr/checkmatrix/data/author.cfg"
set Info(debug) 0
reset
#set window(img) "$BinDir/etc/warning_promis.gif"
#warning $window(warning) $window(img)
        wm withdraw .
        wm geometry . {}
#        toplevel .buttonMenu
#        wm overrideredirect .buttonMenu true
#        label .buttonMenu.l -bg #9478FF -fg white -text "OCR test"
#        button .buttonMenu.debug -text test -bg green -fg black -command {
#		warning $window(warning)  "$BinDir/etc/warnning.gif"
#        }
#        pack .buttonMenu.l .buttonMenu.debug -side top -expand yes -fill both
#       wm geometry .buttonMenu "-0-150"
#        wm deiconify .buttonMenu

