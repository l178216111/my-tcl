#!/usr/local/bin/wctksh_3.2

proc WriteFile { filename text } {

	set fp [open $filename "a+"]
	puts $fp $text
	close $fp
}

proc heartbeatcheck { state } {
	global Info env promisname
    if { $state == "start" } {
		after cancel $Info(after_id)
        set Info(after_id) [after [expr {int($env(HeartBeat_Period) * 1000)}] heartbeatcheck start]
		if {$Info(isFirstCheck) == 1} {
		set	Info(isFirstCheck) 0
		} else {
#		Msg_To_TTT_HeartBeat
		 set comments "Heartbeatcheck"
		 set msg [Generate_EPR_Msg  "" "$promisname \"\" \"\" true" "" "EQUIP_INFO" " \"COMMENTS $comments \" " ""]
	   	 Log "heartbeatcheck sending: $msg"
		 Msg_To_TTT $msg
		 }
    } elseif { $state == "stop" } {
		Log "stopping heartbeatcheck"
        after cancel $Info(after_id)
		set Info(isFirstCheck) 1
    }	
	}

proc evrinfomessage {station message} {
	
	 global Info SOW EOW  env promisname
	 	
	if {[ regexp {RETEST} $message ]} {
		set Info(isReprobe) 1
	} else {
		set Info(isReprobe) 0
	}
 
}

proc evrwaferinfo {station wafer_id passnumber subpass xrefoffset yrefoffset yield testtable zwindow} {
 
        global Info SOW EOW  env promisname
 
        set WaferId $wafer_id
        set temp [split $WaferId -]
        set Info(Wafer) [lindex $temp 1]
	    set Info(Event) "waferinfo"
		set Info(State) ""
        set Info(Pass) $passnumber
		set Info(Host) [eval exec "hostname"]
        if {$Info(Wafer) == ""} {
			set Info(Wafer) 0
        } 
        
		Log "waferinfo:: wafer=$wafer_id pass=$passnumber subpass=$subpass "		
}

proc evrcellstatus { station cellID label[] operatorID waferID state deviceType lotName totalWafers lastWafer runningYield waferYield[]} {

  global Info SOW EOW AS env promisname SOL
  
	set Info(CellID) $cellID
	set Info(Station) $station
	set Info(Device) $deviceType
	set Info(LotID) $lotName
	set Info(OperID) $operatorID
	set Info(State) $state
	set Info(Event) "cellstatus"
	set datestring [clock seconds]
	set datestring [clock format $datestring -format %Y-%m-%dT%H:%M:%S]
	Log "cellstatus: state=$state lot=$lotName totalWafers=$totalWafers lastWafer=$lastWafer "


	 if {$Info(State) == "Lot_start"} {
		 set SOL 1
		 set LS_stn$Info(Station) 1
		 set ProLoad_Start  $datestring
		 set Info(LastEventTime) $datestring
		 set comments "Lot_Start"
		 ##??Generate_EPR_Msg "" "" "" "" "" ""
	   	 set msg [Generate_EPR_Msg  "Productive" "$promisname \"\" \"\" true" "" "EQUIP_START" "\"SUBSTATE Running \" \"LOT_ID  $Info(LotID) \" \"DEVICE_ID $Info(Device)  \" \"REPROBE $Info(isReprobe)  \" \"COMMENTS $comments \" \"OPERATOR_ID $Info(OperID)  \" \"PROBECARD_ID $Info(PCID)  \" \"PROBECARD_TYPE $Info(PCType) \" \"WAFER_ID $Info(Wafer) \" \"PASS  $Info(Pass)\" " ""]
		 Log "Lot start sending:: $msg " 
		 Msg_To_TTT $msg
		 
		 heartbeatcheck stop 
		 heartbeatcheck start
   } 

	  if {$Info(State) == "Pause"} {
		  
		 if {$SOW == 1 && $AS == 0} {
		 set Test_End_Alarm_Start  $datestring
		 set Test_Start $Info(LastEventTime) 
		 
		 set Test_End_Alarm_Start_second  [clock scan $Test_End_Alarm_Start]
		 set Test_Start_second  [clock scan $Test_Start]
		 set Test_Time  [expr $Test_End_Alarm_Start_second - $Test_Start_second]
		 set Info(TestTime) $Test_Time
		 set Info(TestTimeWafer) [expr $Info(TestTimeWafer) + $Info(TestTime)]
		 set Info(LastEventTime) $datestring
		 }
		 if {$AS == 1} {
			 
		 set comments "Pause"
		 set msg [Generate_EPR_Msg  "Unscheduled Down" "$promisname \"\" \"\" true" "" "EQUIP_INFO" "\"SUBSTATE Ualarm \" \"LOT_ID  $Info(LotID) \" \"DEVICE_ID $Info(Device)  \" \"REPROBE $Info(isReprobe)  \" \"COMMENTS $comments \" \"OPERATOR_ID $Info(OperID)  \" \"PROBECARD_ID $Info(PCID)  \" \"PROBECARD_TYPE $Info(PCType) \" \"WAFER_ID $Info(Wafer) \" \"PASS  $Info(Pass)\" " ""]
		 Log "Pause sending:: $msg"
		 Msg_To_TTT $msg
		 
				} else {
					
		 set comments "Pause"
		 set msg [Generate_EPR_Msg  "Unscheduled Down" "$promisname \"\" \"\" true" "" "ALARM_SET" "\"SUBSTATE Ualarm \" \"LOT_ID  $Info(LotID) \" \"DEVICE_ID $Info(Device)  \" \"REPROBE $Info(isReprobe)  \" \"COMMENTS $comments \" \"OPERATOR_ID $Info(OperID)  \" \"PROBECARD_ID $Info(PCID)  \" \"PROBECARD_TYPE $Info(PCType) \" \"WAFER_ID $Info(Wafer) \" \"PASS  $Info(Pass)\" " ""]
		 Log "Pause sending:: $msg"
		 Msg_To_TTT $msg
						}
		 set Info(TestTime) 0

		 heartbeatcheck stop 
		 heartbeatcheck start	
		 set AS 1
	 }
			
	if {$Info(State) == "Alarm"} {
		 if {$SOW == 1 && $AS == 0} {
		 set Test_End_Alarm_Start  $datestring
		 set Test_Start $Info(LastEventTime) 
		 
		 set Test_End_Alarm_Start_second  [clock scan $Test_End_Alarm_Start]
		 set Test_Start_second  [clock scan $Test_Start]
		 set Test_Time  [expr $Test_End_Alarm_Start_second - $Test_Start_second]
		 set Info(TestTime) $Test_Time
		 set Info(TestTimeWafer) [expr $Info(TestTimeWafer) + $Info(TestTime)]
		 set Info(LastEventTime) $datestring
		 }
		 if {$AS == 1} {
			 
		 set comments "Alarm"
	     set msg [Generate_EPR_Msg  "Unscheduled Down" "$promisname \"\" \"\" true" "" "EQUIP_INFO" "\"SUBSTATE Ualarm \" \"LOT_ID  $Info(LotID) \" \"DEVICE_ID $Info(Device)  \" \"REPROBE $Info(isReprobe)  \" \"COMMENTS $comments \" \"OPERATOR_ID $Info(OperID)  \" \"PROBECARD_ID $Info(PCID)  \" \"PROBECARD_TYPE $Info(PCType) \" \"WAFER_ID $Info(Wafer) \" \"PASS  $Info(Pass)\" " ""]
   	     Log "Pause sending:: $msg"
		 Msg_To_TTT $msg
		 
									} else {
										
		 set comments "Alarm"
         set msg [Generate_EPR_Msg  "Unscheduled Down" "$promisname \"\" \"\" true" "" "ALARM_SET" "\"SUBSTATE Ualarm \" \"LOT_ID  $Info(LotID) \" \"DEVICE_ID $Info(Device)  \" \"REPROBE $Info(isReprobe)  \" \"COMMENTS $comments \" \"OPERATOR_ID $Info(OperID)  \" \"PROBECARD_ID $Info(PCID)  \" \"PROBECARD_TYPE $Info(PCType) \" \"WAFER_ID $Info(Wafer) \" \"PASS  $Info(Pass)\" " ""]
		 Log "Pause sending: $msg"
		 Msg_To_TTT $msg
		 
		 }
     	 set Info(TestTime) 0
		 set AS 1

		 heartbeatcheck stop 
		 heartbeatcheck start
	 }
	 
	 if {$Info(State) == "First_die"} {
		 set SOW 1
		 set EOW 0
		 
		 if {$SOL == 1} {
		 set SOL 0
		 set ProLoad_Stop  $datestring
		 set ProLoad_Start $Info(LastEventTime)
		 set ProLoad_Stop_second  [clock scan $ProLoad_Stop]
		 set ProLoad_Start_second  [clock scan $ProLoad_Start]
		 set ProLoad_Time  [expr $ProLoad_Stop_second - $ProLoad_Start_second]
		 set Info(ProLoadTime) $ProLoad_Time
		 }
		 set Info(LastEventTime) $datestring
		 
		 set comments "First_Die"
	     set msg [Generate_EPR_Msg  "Productive" "$promisname \"\" \"\" true" "" "EQUIP_START" "\"SUBSTATE Running \" \"LOT_ID  $Info(LotID) \" \"DEVICE_ID $Info(Device)  \" \"REPROBE $Info(isReprobe)  \" \"COMMENTS $comments \" \"OPERATOR_ID $Info(OperID)  \" \"PROBECARD_ID $Info(PCID)  \" \"PROBECARD_TYPE $Info(PCType) \" \"WAFER_ID $Info(Wafer) \" \"PASS  $Info(Pass)\" " " \"PROGRAM_LOAD_TIME  $Info(ProLoadTime) \" "]
		 Log "First_die sending: $msg" 
		 Msg_To_TTT $msg
		 
     	 set Info(ProLoadTime) 0
		 
		 heartbeatcheck stop 
		 heartbeatcheck start
	 }
		  	
	 if {$Info(State) == "Idle"} {
		 set EOW 0
	 }
	
	 if {$Info(State) == "Wafer_end"} {
		 set EOW 1	
		 set Info(isReprobe) 0	 		 
	 }	
	 
	if {$Info(State) == "Lot_end"} {
		 set SOW 0
		 set Info(WafersProcessed) 0
	 }	
	 
	 if {$Info(State) == "Testing"} {
		 if {$AS == 1} {
		 set Alarm_End_Test_Start  $datestring
		 set Alarm_Start $Info(LastEventTime) 
		 
		 set Alarm_End_Test_Start_second  [clock scan $Alarm_End_Test_Start]
		 set Alarm_Start_second  [clock scan $Alarm_Start]
		 set Alarm_Time  [expr $Alarm_End_Test_Start_second - $Alarm_Start_second]
		 set Info(AlarmTime) $Alarm_Time
		 
		 set comments "Testing"
         set msg [Generate_EPR_Msg  "Productive" "$promisname \"\" \"\" true" "" "ALARM_CLEAR" "\"SUBSTATE Running \" \"LOT_ID  $Info(LotID) \" \"DEVICE_ID $Info(Device)  \" \"REPROBE $Info(isReprobe)  \" \"COMMENTS $comments \" \"OPERATOR_ID $Info(OperID)  \" \"PROBECARD_ID $Info(PCID)  \" \"PROBECARD_TYPE $Info(PCType) \" \"WAFER_ID $Info(Wafer) \" \"PASS  $Info(Pass)\" " " \"ALARM_TIME $Info(AlarmTime) \" "]
		 Log "Testing sending: $msg"
		 Msg_To_TTT $msg
		 
		 set Info(AlarmTime) 0

		 heartbeatcheck stop 
		 heartbeatcheck start
		 }
		 set Info(LastEventTime) $datestring
		 set AS 0
	 }		
}

proc evrerrormessage { station severity errno message } {
	global Info AS env
	}
	
proc evrprobecardevent { station tyPerfEvent npolish ntouch pcID pcType sites[]} {
	global Info env promisname
	Log "probecardevent: pcID=$pcID pcType=$pcType PerfEvent=$tyPerfEvent npolish=$npolish ntouch=$ntouch"
	set Info(NumPolish) $npolish
	set Info(PcType) $pcType
	set Info(PCID) $pcID
	set Info(NTouch) $ntouch

    set host [exec hostname]

	set datestring [clock seconds]
	set datestring [clock format $datestring -format %Y-%m-%dT%H:%M:%S]
        set pbid 0
        set zwin 0
        set touch_incr $Info(StepCount_$Info(Wafer))
	
	if { [ regexp {PcEndOfWafer} $tyPerfEvent ] } {
		
#		set cmd "$BinDir/update_pcts $host $Info(PCID) $touch_incr $pbid $Info(NumPolish) $zwin $Info(Device) $Info(LotID) $Info(Wafer) $Info(Pass) $datestring"
#        	if { [catch {eval exec $cmd} err] } {
#                	WriteFile $ErrFile "evr_monitor.EndOfWafer ERROR can not upload pcts info, $datestring $host $Info(PCID) $Info(Device) $Info(LotID) $Info(Wafer) $Info(Pass) $Info(OperID) "
#        	} else { 
#			WriteFile $LogFile "$datestring $host $Info(PCID) $touch_incr $pbid $Info(NumPolish) $zwin $Info(Device) $Info(LotID) $Info(Wafer) $Info(Pass) $Info(OperID) "
#			}

		 set comments "ProbeCardEvent_EndOfWafer"
		 if { $Info(isReprobe) == 1} {
			set Info(TestTimeWafer) $Info(TestTime)
			set comments "ProbeCardEvent_EndOfWafer_Reporbe"
			set Info(WafersProcessed) 0
			set Info(TestTime) 0
		 } 	

		set msg [Generate_EPR_Msg  "Productive" "$promisname \"\" \"\" true" "" "EQUIP_INFO" "\"SUBSTATE Running \" \"LOT_ID  $Info(LotID) \" \"DEVICE_ID $Info(Device)  \" \"REPROBE $Info(isReprobe)  \" \"COMMENTS $comments \" \"OPERATOR_ID $Info(OperID)  \" \"PROBECARD_ID $Info(PCID)  \" \"PROBECARD_TYPE $Info(PCType) \" \"WAFER_ID $Info(Wafer) \" \"PASS  $Info(Pass)\" " " \"TOUCH_INCREMENT $Info(NTouch) \" \"NUMBER_POLISH $Info(NumPolish) \" \"WAFERS_PROCESSED $Info(WafersProcessed)\" \"DEVICES_PROCESSED  $Info(DevicesProcessed) \" \"CNT_GOOD  $Info(CNTGood) \" \"TEST_TIME $Info(TestTimeWafer) \"  "]
	   	Log "Sending: $msg "
		 Msg_To_TTT $msg
		set Info(LastEventTime) $datestring
		set Info(StepCount_$Info(Wafer)) 0
		set Info(TestTimeWafer) 0
		
		 heartbeatcheck stop 	 
		 heartbeatcheck start
		}
		set touch_incr 0
		set Info(StepCount_$Info(Wafer)) 0
				
}

####################################################################################
# To find out the touch down count of the probe card                               #
####################################################################################
proc evrstepcount {station steps} {
        global Info env

        # Initialize step count for each wafer at the every beginning since this may
        # not be available later for unit probe

        for {set i 1} {$i <= 25} {incr i} {
                if { $Info(StepCount_${i}) == 0 } {
                        set Info(StepCount_${i}) $steps
                }
        }

        set Info(StepCount_$Info(Wafer)) $steps
		Log "stepcount: steps=$steps"
		
}

proc evrendoflot {station} {
	global Info SOW EOW env promisname
	
	    set datestring [clock seconds]
		set datestring [clock format $datestring -format %Y-%m-%dT%H:%M:%S]
#		set Lot_Test_End  $datestring
#		set Test_Start $Info(LastEventTime) 
#		 
#		set Lot_Test_End_second  [clock scan $Lot_Test_End]
#		set Test_Start_second  [clock scan $Test_Start]
#		set Test_Time  [expr $Lot_Test_End_second - $Test_Start_second]
#		set Info(TestTime) $Test_Time
		set Info(LastEventTime) $datestring
		
		set comments "End_of_Lot"
####### set the lot and device to "Unknown" in the evr when changing the tool to idle		
#       set msg [Generate_EPR_Msg  "Standby" "$promisname \"\" \"\" true" "" "EQUIP_STOP" "\"SUBSTATE Idle \" \"LOT_ID  $Info(LotID) \" \"DEVICE_ID $Info(Device)  \" \"REPROBE $Info(isReprobe)  \" \"COMMENTS $comments \" \"OPERATOR_ID $Info(OperID)  \" \"PROBECARD_ID $Info(PCID)  \" \"PROBECARD_TYPE $Info(PCType) \" \"WAFER_ID $Info(Wafer) \" \"PASS  $Info(Pass)\" " ""]
		set msg [Generate_EPR_Msg  "Standby" "$promisname \"\" \"\" true" "" "EQUIP_STOP" "\"SUBSTATE Idle \" \"LOT_ID  Unknown \" \"DEVICE_ID Unknown \" \"REPROBE Unknown \" \"COMMENTS $comments \" \"OPERATOR_ID Unknown \" \"PROBECARD_ID Unknown \" \"PROBECARD_TYPE Unknown \" \"WAFER_ID Unknown \" \"PASS  Unknown \" " ""]
      
		Log "endoflot sending: $msg"
		Msg_To_TTT $msg

		heartbeatcheck stop 
			
	if {$env(PCTS_Function) == "Y" } {	
		if { $Info(isOverLimits) == 0 } {
			if {$env(debug) == 1} {
			puts "#### check card in lot_end"
			}
			Check_Card $Info(PCID) $station
		}
		if { $Info(isOverLimits) == 1 && $Info(isWarned) != 1} {
		#comment out for testing--Kevin
		######################
			dialog .warn {Card expired} {} warn.gif -1 OK
		#####################
		}
	}
	Reset_Info
	}
	

proc evrendofwafer { station wafer_id cassette slot num_pass num_tested start_time end_time lot_id } {

	global Info env EOW SOW promisname
	Log "endofwafer: lot_id=$lot_id wafer_id=$wafer_id slot=$slot num_pass=$num_pass num_tested=$num_tested start_time=$start_time end_time=$end_time"
	set datestring [clock seconds]
	set datestring [clock format $datestring -format %Y-%m-%dT%H:%M:%S]
	
	set partid $Info(Device)
	set passnum $Info(Pass)
	
	set Info(DevicesProcessed_$Info(Wafer)) $num_tested
 	set Info(CNTGood_$Info(Wafer)) $num_pass
	
	if { $Info(isReprobe) == 1} {
		set CNTGood_Probe $Info(CNTGood)
	set Info(DevicesProcessed) [expr $num_tested-$Info(CNTGood)]
	set Info(CNTGood) [expr $num_pass-$CNTGood_Probe]
		} else {

 	set Info(DevicesProcessed) $num_tested
 	set Info(CNTGood) $num_pass	
	}
 
		set Wafer_Test_End  $datestring
		set Test_Start $Info(LastEventTime) 
		 
		set Wafer_Test_End_second  [clock scan $Wafer_Test_End]
		set Test_Start_second  [clock scan $Test_Start]
		set Test_Time  [expr $Wafer_Test_End_second - $Test_Start_second]
		set Info(TestTime) $Test_Time
		set Info(TestTimeWafer) [expr $Info(TestTimeWafer) + $Info(TestTime)]


	if { $SOW == 1} { 
 	set Info(WafersProcessed) 1
	set SOW 0
	}

###############################
##### CR2 
	if {$env(PCTS_Function) == "Y" && $env(OverTouchdown_Check_WAFER) == "Y" } {		
	set cmd "grep $partid $env(EVRDir)/pcts_config | grep -v # | head -1"

	if [ catch { set Line [ eval exec $cmd ] } err ] {
		WriteFile $env(ErrFile) "EndOfWafer ERROR happen when execute $cmd"	
	} else {
		set SORT [lindex [split $Line ":"] 1 ]
		set PCR_Group [lindex [split $Line ":"] 2 ]
		set PCID_head [lindex [split $Info(PCID) "-"] 0 ]	
		if { [ regexp "$PCID_head" $PCR_Group ] && $SORT == $passnum } {
			if { $Info(isOverLimits) == 0 } {
				if {$env(debug) == 1} {
				puts "#### check card in wafer_end"
				}
				Check_Card $Info(PCID) $station
			}

		}		
	}
	}
###############################	
	
		 heartbeatcheck stop 
		 heartbeatcheck start	
}

	
proc evrprobecarddefine {station pcID pcType args} {
        global Info env promisname
		Log "probecarddefine: pcID=$pcID pcType=$pcType"
        set Info(PCID) $pcID
		set Info(PCType) $pcType
#####		
		if {$env(PCTS_Function) == "Y"} {
			if {$env(debug) == 1} {
			puts "#### check card in probecard_define"
			}
        	Check_Card $Info(PCID) $station
#####CR_TJN
			set LotID_Start [string range $Info(LotID) 0 0]
			set ToolID_Last3 [string range $promisname end-2 end] 
			if { $LotID_Start != "C" && $LotID_Start != "K" && $LotID_Start != "G" && $env(PCTS_Function) == "Y" && $env(Check_Card_Message) != "N" && $ToolID_Last3 != "INK"} {
				Check_Card_State $Info(PCID) $station
				if {$Info(isValidCard) != "Y"} {
					    evr send pause $station
						evr send abortlot $station
               			evr send reset $station
						dialog .warn {Card not Valid} {} warn_card.gif -1 OK

#					Warning_Dialog .faildelta $station
				} 
				
			} 		
#####CR_TJN_END
		}
#####

}


proc Check_Card_State { cardID station } {
	#  This never gets called unless env(PCTS_Function) is Y
    #
	global Info env
	set $Info(isValidCard) 0
	
########
	if {[catch {cd $env(CheckFileDir)} err]} {
    	Log "Cannot open the directory $env(CheckFileDir)"
      	break
   	}
	
#	foreach cfile [glob -nocomplain TTT*] {
		cd $env(CheckFileDir)
#	    set checkFile [file join $env(CheckFileDir) $cfile]
	set checkFile "$env(CheckFileDir)/state_pc.txt"
		if {$env(debug) == 1} {
		puts "#### Checking the file:$checkFile"
		}
		if [catch {open $checkFile r} fileId] {
			if {$env(debug) == 1} {
			puts "Cannot open $checkFile: $fileId"
			}
           	Log "Cannot open $checkFile: $fileId"
        } else {
            foreach line [split [read $fileId] \n] {
				if { $line == "Connected." } {
					continue
				}
				if { $line == "Not connected." } {
					set datestring [clock seconds]
					set datestring [clock format $datestring -format %Y-%m-%dT%H:%M:%S]
#				set touchFile "$LogDir/touchlog1"
#				WriteFile $touchFile "$datestring touch down database query failed probing $Info(Device)-$Info(LotID)\n"
					Log "$datestring touch down database query failed probing $Info(Device)-$Info(LotID)\n"
					break
				}
				set ID [ lindex [ split $line , ] 0 ]
#				set Use [ lindex [ split $line , ] 1 ]
#				set Lim [ lindex [ split $line , ] 2 ]
#				if { $Use == "" } {
#					break
#				}
#
					if { $cardID == $ID } {
						
						set Info(isValidCard) "Y"

                    close $fileId
					return 1
                }
          	}
			close $fileId
			if {$env(debug) == 1} {
			puts "#### Card is not valid"
			}
        }
#	}
	if {$env(debug) == 1} {
	puts "#### Card is not valid"
	}
}

proc Check_Card { cardID station } {
	#  This never gets called unless env(PCTS_Function) is Y
    #
	global Info env
	
########
	if {[catch {cd $env(CheckFileDir)} err]} {
    	Log "Cannot open the directory $env(CheckFileDir)"
      	break
   	}
	
	foreach cfile [glob -nocomplain TTT*] {
		cd $env(CheckFileDir)
	    set checkFile [file join $env(CheckFileDir) $cfile]
#	set checkFile "$env(EVRDir)/overtouchdown_pc.txt"
		if {$env(debug) == 1} {
		puts "#### Checking the file:$checkFile"
		}
		
		if {[file isfile $checkFile]} {
		
		if [catch {open $checkFile r} fileId] {
           	Log "Cannot open $checkFile: $fileId"
        } else {
            foreach line [split [read $fileId] \n] {
				if { $line == "Connected." } {
					continue
				}
				if { $line == "Not connected." } {
					set datestring [clock seconds]
					set datestring [clock format $datestring -format %Y-%m-%dT%H:%M:%S]
#				set touchFile "$LogDir/touchlog1"
#				WriteFile $touchFile "$datestring touch down database query failed probing $Info(Device)-$Info(LotID)\n"
					Log "$datestring touch down database query failed probing $Info(Device)-$Info(LotID)\n"
					break
				}
				set ID [ lindex [ split $line , ] 0 ]
				set Use [ lindex [ split $line , ] 1 ]
				set Lim [ lindex [ split $line , ] 2 ]
				if { $Use == "" } {
					break
				}

                if { $cardID == $ID } {

				#only modify $Info(isOverLimits) flag in check proc
					set Info(isOverLimits) 1

					if {$env(PCTS_Function) == "Y"} {
						set Info(isWarned) 1	
     		    		evr send pause $station
               			evr send reset $station
						dialog .warn {Card expired} {} warn.gif -1 OK
						}

					set datestring [clock seconds]
					set datestring [clock format $datestring -format %Y-%m-%dT%H:%M:%S]
	
					Log "$datestring $Info(PCID) expired PCR $Use/$Lim probing $Info(Device)-$Info(LotID)\n"
                    close $fileId
					return 1
                }
          	}
			close $fileId
			if {$env(debug) == 1} {
			puts "#### No card found in the file $checkFile"
			}
        }
	}
}
	if {$env(debug) == 1} {
	puts "#### No card found in all files."
	}
}

proc Warning_Dialog {window station} {
#        global Info YMBIN YMLOG Debug_Flag Window ignore_record_file Category 
	global button env Window Station Info

        set Station $station
		set Window  $window
        if { ! [winfo exists .warnwin] } {
                toplevel  .warnwin
                wm title  .warnwin "Warning Message Window"

                label     .warnwin.l
                pack      .warnwin.l -side top -fill x

                frame     .warnwin.f1
                pack      .warnwin.f1 -side left -fill y -padx 10 -pady 10
		
#		set contactstring [ eval exec "cat $YMBIN/contactlist"]

               	#message   .warnwin.f1.msg -aspect 400 -text $env(Check_Card_Message)
#				message   .warnwin.f1.msg -aspect 400 -text "ÄãºÃ"
				set map "$env(EVRDir)/warn_card.gif"
				set im [image create photo -file $map]
				label .warnwin.f1.image -image $im           
                pack .warnwin.f1.image -side top -padx 5m -pady 5m
#	            pack      .warnwin.f1.msg -side top -fill x
#                button    .warnwin.f1.b1 -text "Exit with No Change" -command {destroy .warnwin}
               	button    .warnwin.f1.b2 -bg red -text "Confirm " -command {

			catch { set time [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S" ] }
			global Info Debug_Flag 
			set result "N/A"
			set login_counter 1
			set USER_AUTH "fail"

						while { [string last "fail" $USER_AUTH] >= 0 && $login_counter <= 3 } {
						if {$env(debug) == 1} {
               			puts "USER_AUTH is $USER_AUTH, into the loop"
						}
               			set USER_AUTH [eval exec "$env(EVRDir)/login_screen"]
						if {$env(debug) == 1} {
						puts "#####USER_AUTH is $USER_AUTH"
						}
#               			set cmd "grep $USER_AUTH $EVRDir/contactlist"
               			incr login_counter
#               			if [catch {set result [ eval exec "$cmd" ] } err] {
#                       			if {[ file exist $Debug_Flag ] } {
#                               			writeFile $YMLOG "Warning_Dialog ERROR happen when execute $cmd"
#                       			}
#               			} else {
#                       			if {[ file exist $Debug_Flag ] } {
#                               			writeFile $YMLOG "Warning_Dialog ERROR, $result and $USER_AUTH"
#                       			}
#               			}
				if {$env(debug) == 1} {
				puts "USER_AUTH is $USER_AUTH, into the loop end"
				}
               		}

        		if { $login_counter <= 3 } {
				if {$env(debug) == 1} {
				puts "$USER_AUTH disable the card check at $time @ $Info(PCID)" 
				}
				Log "ProbeCardChecking User $USER_AUTH disable the card check at $time @CardID $Info(PCID) @ToolID $promisname"
#				writeFile $YMLOG "$USER_AUTH disable the card check"
#                                writeFile $ignore_record_file $Info(label_string)
                                evr send start $Station
                                destroy $Window
                        }
			destroy .warnwin
			if { [winfo exists $Window] } {
				focus -force $Window
			}
		}
#               	pack      .warnwin.f1.b1 .warnwin.f1.b2 -side bottom -fill x
		pack      .warnwin.f1.b2 -side bottom -fill x
		focus -force .warnwin
	}
}

proc dialog {w title text bitmap default args} {
	global button EVRDir env
	# 1. Create the top-level window and divide it into top
	# and bottom parts.
	toplevel $w -class Dialog
	wm title $w $title
	wm iconname $w Dialog
	frame $w.top -relief raised -bd 1
	pack $w.top -side top -fill both
	frame $w.bot -relief raised -bd 1
	pack $w.bot -side bottom -fill both
	# 2. Fill the top part with the bitmap and message.
	message $w.top.msg -width 3i -text $text \
		-font -Adobe-Times-Medium-R-Normal-*-180-*
	pack $w.top.msg -side right -expand 1 -fill both \
		-padx 5m -pady 5m
	if {$bitmap != ""} {
		set map "$env(EVRDir)/$bitmap"
		set im [image create photo -file $map]
		label $w.top.image -image $im           
                pack $w.top.image -side left -padx 5m -pady 5m
	}
	# 3. Create a row of buttons at the bottom of the dialog.
	set i 0
	foreach but $args {
		button $w.bot.button$i -text $but -command \
			"set button $i"
		if {$i == $default} {
			frame $w.bot.default -relief sunken -bd 1
			pack $w.bot.default -side left -expand 1\
				-padx 5m -pady 2m
			pack $w.bot.button$i -in $w.bot.default -side left\
				-padx 3m -pady 3m -ipadx 2m -ipady 1m
		} else {
			pack $w.bot.button$i -side left -expand 1 \
				-padx 5m -pady 5m -ipadx 2m -ipady 1m
		}
			incr i
	}
	# 4. Set up a binding for <Return>, if there¡¯s a default,
	# set a grab, and claim the focus too.
	if {$default > 0} {
		bind $w <Return> "$w.bot.button$default flash; \
		set button $default"
	}
	set oldFocus [focus]
	grab $w
	focus $w
	# 5. Wait for the user to respond, then restore the focus
	# and return the index of the selected button.
	tkwait variable button
#	focus -force $w.bot.button$i
	destroy $w
	focus $oldFocus
	return $button
}			

proc evrstartoflot {station} {

        global Info env
	    Log "startoflot"
        set partid $Info(Device)
        set passnum $Info(Pass)
#        set cmd "grep $partid $env(BinDir)/pcts_config | grep -v # | head -1"

        set datestring [clock seconds]
		set datestring [clock format $datestring -format %Y-%m-%dT%H:%M:%S]
	    set Test_Start $datestring

#		if {$env(PCTS_Function) == "Y"} {
#             Check_Card $Info(PCID) $station
#			 }

}

proc evrstartofwafer {station} {

        global Info env
	    Log "startofwafer"
        set partid $Info(Device)
        set passnum $Info(Pass)	
###############################
##### CR2 
	if {$env(PCTS_Function) == "Y" && $env(OverTouchdown_Check_WAFER) == "Y" } {
	set cmd "grep $partid $env(EVRDir)/pcts_config | grep -v # | head -1"

	if [ catch { set Line [ eval exec $cmd ] } err ] {
		WriteFile $env(ErrFile) "EndOfWafer ERROR happen when execute $cmd"	
	} else {
		set SORT [lindex [split $Line ":"] 1 ]
		set PCR_Group [lindex [split $Line ":"] 2 ]
		set PCID_head [lindex [split $Info(PCID) "-"] 0 ]	
		if { [ regexp "$PCID_head" $PCR_Group ] && $SORT == $passnum } {
			if { $Info(isOverLimits) == 0 } {
				if {$env(debug) == 1} {
					puts "#### check card in start of wafer"
				}
				Check_Card $Info(PCID) $station
			}

		}	
		
	}
	}
###############################	
}

proc Log { msg } {
	global env

	if [catch {open $env(LogFile) a} fileID] {
	   return "No log, unable to open file"
	}
	if {[file size $env(LogFile)] > $env(MaxLogSize) } {
	   close $fileID
	   file rename -force $env(LogFile) ${env(LogFile)}2
	   catch {open $env(LogFile) a} fileID
	}
	puts $fileID "[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S} ] $msg"
	close $fileID
	return ""
}

proc Reset_Info { } {
	
	global Info promisname

	set Info(Device) 0
	set Info(Wafer) 0
	set Info(LotID) 0
	set Info(Pass) 0
	set Info(OperID) 0
	set Info(Station) 0
	set Info(State) 0
	set Info(PCID) 0
	set Info(PCType) 0
	set Info(CellID) 0
	set Info(TestProgram) 0
	set Info(Temperature) 0
	set Info(Retest) 0
	set Info(SitesAbailable) 0
	set Info(HandlerID) 0
	set Info(Loadboard_ID) 0
	set Info(Insertions) 0
	set Info(DevicesProcessed) 0
	set Info(CNTGood) 0
	set Info(TestTime) 0
	set Info(HNDIndexTime) 0
	set Info(ProLoadTime)  0
	set Info(ValidationTime) 0
	set Info(AlarmTime) 0
	set Info(NumPolish) 0
	set Info(NTouch) 0
	set Info(isOverLimits) 0
	set Info(Host) [eval exec hostname] 
	set Info(LastEventTime) [clock seconds]
	set Info(WafersProcessed) 0
	set Info(after_id) 0
	set Info(isReprobe) 0
	set	Info(isFirstCheck) 1
	set Info(TestTimeWafer) 0
	set Info(isWarned) 0
	set Info(isValidCard) 0
	
		for {set i 0} {$i <= 25} {incr i} {
    		set Info(StepCount_${i}) 0
	}

}

wm overrideredirect . true
wm withdraw .

evr connect localhost

#bind the evrs
if [catch {source $env(EVRDir)/Bind_TTT_EVR.tcl} result] {
	Log "Initialization file not found: $result."
} 

if [catch {source $env(EVRDir)/Generate_EPR_Msg.tcl} result] {
	Log "Failed to generate the EPR++ Message: $result."
} 

if [catch {source $env(EVRDir)/Msg_To_TTT.tcl} result] {
	Log "Failed to send the EPR++ Message to TTT: $result."
} 

set promisname None
set SOW 0
set EOW 0 
set AS 0
set SOL 0
set Retry_Times 0
set after_id 0

if [ info exists env(PROMIS_NAME) ] {
    set promisname $env(PROMIS_NAME)
} else {
    set promisname [exec hostname]
}

	Reset_Info
