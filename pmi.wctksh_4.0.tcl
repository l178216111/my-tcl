#!/usr/local/bin/wctksh_3.2

#####################################################
# Version 4. update by Jiang Nan
# Release notes:
#	1. change log format. 
#	2. fix bump issue. jump out while dut == -1
#	3. re-align wafer interval for pre-pmi. add a new global variable flag4PrePMI. below for details:
#		a. flag4PrePMI = -1  <= status for cancel "prepmi"
#		b. flag4PrePMI =   <= status for initial/default value.
#		c. flag4PrePMI = 1  <= status for "prepmi" trigger
#		d. flag4PrePMI = 2  <= status for "prepmi" cross current wafer.
#		e. flag4PrePMI = 3  <= status for "PMI" done
#

#####################################################
#
# Version 3.9a updated by Jiang Nan
# Release notes:
#	1. Fix the get wafer id function to support integrator4. and a versions.
#	2. Add support for Auto-Corr function(for CPLE).
#	3. Fix the tolerant function bypass 1st PMI issue.
#
#

# Revision 3.8u updated by JN
#	Add a prompt window when operator wants to delay pre-pmi
#	    and write them to pmi log , flag variable : $proceed_prog : Delay_PrePMI ; flag4PMI_No_Button 
#
#	In this version,if you click No button on both Pre-PMI and PMI,it'll bring you back to the time that PMI(Pre-PMI) triggered
#
#	Replace \"\" in Info variable with "" 
#
#	Add three function to support prompt window at last
#
# Revision 3.8
#
# 21.4.28
#    Add PMI status for floorview.
#        flag file: opid_prechecking opid_pmichecking
#    Add open file monitor 
#        abort lot if open config file error

# Revision 3.7
#
# 29.8.5
#    Add extra top wafers setup. This will allow PMI stop at top of certain wafers .
#    extratopwafers:2,3,4
# 29.8.1
#    Fix the twice trigger issue when auto-reprobe happens.
# 29.8.19
#    Add code to make sure when end of lot, the PMI window is destoried and reset.
#    Add Info(SOL) variable. When SOL, set Info(SOL) 1. When EOL, set Info(SOL) .
#        When set Info(SOL) , TestResults and doPMI return.
#    Add an option to disable pre-PMI
# 29.9.1
#    Add control for error message check. If critical error, abort lot.
# 29.9.3
#    Change the PMI process flow. Ask operator enter password first, then check Probe
#    mark and then continue the probe.
# 29.9.23
#    Bug fix for unbalanced open|close. This will fix the too many files open issue.
# 29.1.14
#    Bug fix for pop up twice when operator performing PMI check. Add code: when detect .shresult_PMI window
#    exists, ignore doPMI
#

# Revision 3.6
#
# 28.9.24
#    move the user authentication into PMI tcl program. This will prevent the operater click on integrator start and TestResults
#    not trigger issue. ( If an external program not return, the whole tcl program stop responding to the IG event. But if it is 
#    an internal frame or tk_dialog, the TestResults procedure can still triggered.)
#
#    Modify it for both clean up PMI authentication and add additional wafer authentication.
#
#    remove focus to reduce the inter-lock for PMI program
#    set up logic to only pause -alarm one time for a PMI stop so no prober information message pop up any more.
#    And destroy the old windows and then pop up now window for PMI, which will make sure it always on the the top.
#
#    Modify Mannually get last wafer num part, to make sure the interface is always on top when stop for this reason.
# 28.1.22
#    change the bypass "evr send -alarm" from one die to two dies. Later can change to more if want.
#    bug fix for Proceed_Probe function: add opid_alert opid_pause as global variables
#    add output for wrong password or program error during login verify: Show_Result
# 28.11.4
#    Change second die not trigger pause check to site level, since multi-duts parts will trigger multiple times TestResults.
#    Add the function to track tester operation owner for the station.
# 28.11.1
#    Change the Login display with GRID. This will map up the columns well.
#
# 28.11.24
#    Add die level comments and change the tolerant range to 1-16 to tolerate the muti-dut part such L31N
# 28.12.15
#    Add production work load flag and log output
# 29.1.15
#    Bug Fix for J971 date command: date +2%y%m%d-%H%M%S
#    Bug Fix for J75 some tester Pre_PMI not pop up: suspect reason is LastPMIDie not reset
#    Bug Fix for limit reading. Now more simple. and fix a bug in limit file also.
#    Add the record for stop diex and diey.
# 29.2.17
#    Add debug comments for Pre-PMI not working issue
#    Change revision to 3.6E
# 29.4.24
#    Modify line: set waferID [ format "%2d" [lindex [ split $Info(WaferID) "-" ] 1] ]
#    add catch to prevent the error msg pop-up when end of lot with no wafer start yet.
# 29.7.21
#    Exchange the date command to TCL native command: clock format [ clock seconds ] -format "%Y %m %d - %H:%M:%S"
#    



#
# Revision 3.5
# Modified by Daniel Jin
# 28.6.3
#    Add patrol function. The route set up is in pmi_patrolsetup.txt
#    Add the flag file of opid_alert for Pre-PMI
#    Add the flag file of opid_pause for PMI wait
#    Add the flag file of TestResults in Cell directory, it is for FloorView to show the tester status
#    Add opid_name for record operator name with last PMI
#    change the default stop value to 7 wafers and 1 dies
#    allow corr wafers ( C, KK, GG) bypass the PMI
#    force stop at last wafer -- data is from fablot: /exec/apps/bin/fablots/promis_data/lotinfo1.txt
#    Check if the waferID is in same sequence with PROMIS wafers
#    make sure if no lastwaferID selected, every wafer stop
# 28.7.15
#    change wafer ID compare with PROMIS list logic. since often reprobe(select wafers), the probe sequence is not same as promis.
#    so change the logic to: if the waferID is in PROMIS array, it is OK.
# 28.7.28
#    change to "excludewafers" instead of "excludewafes". Mis-spelling.
# 28.8.5
#    no real change. the issue was caused by fablot file not readable to bat3prb. Change fablot program.
# 28.8.28
#    1. delete all the redundant "evr send pause" and "evr delay" before call doPMI and in doPMI procedure.
#    2. in doPMI procedure use after to replace evr delay. It works better.
#    3. after user input password, start prober, stop again, then start again. This will remove the redundant -alarm message for
#       for "evr send pause -alarm $station". It will help to relief the focus conflict on screen.

#
# Revision 3.4
# Modified by JB. Daniel
# 28.6.23
#    JB added the additional check.
#    Daniel added the exclude wafer function and check waferID format function.
#    Daniel added the limit by pass setup.
#
# Revision 3.3
# Modified by Yong Wang
# 1/12/26 15:16:33
#
# Had the code to look inside pmi_setup.txt for frequencies and stop location
#
# Revision 3.2
# Modified by Yong Wang
# 12/18/23 13:48:15
#
# Added one data field for pause event report
#
# Revision 3.1
# Modified by Yong Wang
# 5/3/23 11:24:49
# 
# Code was spun off from the original yield_monitor script and added
# two new features
# 1) Do PMI twice on every wafer of special setups
# 2) No PMI for bump parts	
#
# Revision 2.
# Modified by Yong Wang
# 4/8/23 1:59:17

#
#
# Probe Mark Inspection monitoring process (initial version 1.) 
# that will replace the old wafer inspection pause code
# Note: PMI monitor will not show up on inkers

###############################################################
# This procedure gets called when integrator issues
# informational messages.  We are interested in parsing the
# setup name out of the string: "Reading setup SETUP"
#
# MOS 12 comments
#
# The call to LoadLimits was added after we moved from
# Integrator 1.5.1 to Integrator 2.2.1.  See the comments in
# the LoadLimits routine for details.
###############################################################
proc InfoMessage { station message } {

	global Info LogFile CumWaferNum
	WriteFile $LogFile "InfoMessage:$message"
#add by jiang for auto-correlation part 	
	if {[ string equal $message "Starting auto-correlation" ] } {
		incr Info(WaferCount) -1
		incr CumWaferNum -1
		set flag_autoCorrelation 1
	}
#end
#add by fengsheng for Bump/Integrator4. pmi to get waferID
	if [regexp {^Starting wafer session ([^ ]+)} $message match wafer] {
		set Info(WaferID) $wafer
	}
#end
	set CURR_TIME [ clock format [ clock seconds ] -format "%Y%m%d%H%M%S" ]

	if [regexp {^Starting lot ([^ ]+)} $message match lot] {
		set Info(LotID) $lot
	}

	if [regexp {^Reading setup ([^ ]+)} $message match setup] {
		set Info(Device) $setup
		LoadConfig
	}
	
	# add by JiangNan for send message to TTT function;
	if {[ regexp {RETEST} $message ]} {
		set Info(isReprobe) 1
	}
#end
	
}

proc LoadConfig {args} {
	global Info LogFile PMI_Info BinDir ExcludeWafersArray ExtraTopWafersArray ExtraWafersArray
	set MOO "NONE"
	set MOO_PASS "NONE"
	if [ catch {set MOO [eval exec "$BinDir/find_moo $Info(Device) $Info(LotID) $PMI_Info"]} err] {
		WriteFile $LogFile "InfoMessage: Error running $BinDir/find_moo $Info(Device) $Info(LotID) $PMI_Info, error: $err"
        genabortlotfunc "SUN System Error"   "Meet system error1 and PMI program can not continue. Please reboot SUN station!!!"  ""  $station
	} else {
		if [ catch {set MOO_PASS [eval exec "$BinDir/find_moo ${Info(Device)}_$Info(PassNumber) $Info(LotID) $PMI_Info"]} err] {
			WriteFile $LogFile "InfoMessage: Error running $BinDir/find_moo ${Info(Device)}_$Info(PassNumber) $Info(LotID) $PMI_Info, error: $err"
			genabortlotfunc "SUN System Error"   "Meet system error2 and PMI program can not continue. Please reboot SUN station!!!"  ""  $station
		}

		if { ! [ string equal $MOO_PASS "NONE" ] } {
		   set MOO $MOO_PASS
		}

		PutsDebug "LoadConfig: processing limit set for ${Info(Device)} $Info(LotID) $Info(PassNumber) in $PMI_Info => MOO = $MOO ."

		if { [ string compare $MOO "NONE" ] ==   } {
			PutsDebug "LoadConfig: return NONE for ${Info(Device)} $Info(LotID) in $PMI_Info"
		} else {
			PutsDebug "LoadConfig: select $MOO in config $PMI_Info"
			set handle [open "$PMI_Info"]
			inf iconfig
			iconfig load $handle
			close $handle
			if [catch { set isetup [iconfig blocks -unique $MOO] } err] {
				PutsDebug "LoadConfig:    read inf block $MOO error - $err"
				set msg "PMI limit file format error. Device=$MOO Error=$err"
				set resp [ tk_dialog .pmireaderr " Error " $msg warning  "PMI limit file format error. Call Data Team." ]
			} else {
				# Read in PMI frequency information
				if [catch { set Info(freq) [$isetup data -noerror freq ] } err] {
					PutsDebug "LoadConfig: Error reading inf data freq - $err"
				} else {
					if { $Info(freq) ==  } {
						set Info(No_PMI) 1
					}
				}		

				# Read in PMI stop information
				if [catch { set Info(Stop_Die_Count) [$isetup data -noerror stop ] } err] {
					PutsDebug "LoadConfig: Error reading inf data stop - $err"
				}
				
				if [catch { set Info(CPLEClass) [$isetup data -noerror cpleclass ] } err] {
					PutsDebug "LoadConfig: Error reading inf data cpleclass - $err"
				} else {
					PutsDebug "LoadConfig: CPLEClass is $Info(CPLEClass)"		
				}

				
				# Read in disablePrePMI information
				if [catch { set Info(disablePrePMI) [$isetup data -noerror disableprepmi ] } err] {
					PutsDebug "LoadConfig: Error reading inf data disableprepmi - $err"
				}

				# Read in extra top wafer PMI information
				if [catch { set Info(Extra_TopWafers) [$isetup data -noerror extratopwafers ] } err] {
					PutsDebug "LoadConfig:    Error reading inf data extra top wafers - $err"
				} else {
					foreach extra_wafer_number  [ split $Info(Extra_TopWafers) "," ] {
						set extra_wafer_number [ string trim $extra_wafer_number ]
						set extra_wafer_number [ string trimleft $extra_wafer_number "" ]
						set ExtraTopWafersArray($extra_wafer_number) 1
					}
				}

				# Read in extra PMI information
				if [catch { set Info(Extra_Wafers) [$isetup data -noerror extrawafers ] } err] {
					PutsDebug "LoadConfig:    Error reading inf data extrawafers  - $err"
				} else {
					foreach extra_wafer_number  [ split $Info(Extra_Wafers) "," ] {
						set extra_wafer_number [ string trim $extra_wafer_number ]
						set extra_wafer_number [ string trimleft $extra_wafer_number "" ]
						set ExtraWafersArray($extra_wafer_number) 1
					}
				}

				# Read in exclude PMI information
				if [catch { set Info(Exclude_Wafers) [$isetup data -noerror excludewafers ] } err] {
					PutsDebug "LoadConfig:    Error reading inf data excludewafers - $err"
				} else {
					foreach exclude_wafer_number  [ split $Info(Exclude_Wafers) "," ] {
						set exclude_wafer_number [ string trim $exclude_wafer_number ]
						set exclude_wafer_number [ string trimleft $exclude_wafer_number "" ]
						set ExcludeWafersArray($exclude_wafer_number) 1
						PutsDebug "LoadConfig: setting ExcludeWafersArray($exclude_wafer_number) to 1"
					}
# add wafer#1 as default exclude Wafer. by JiangNan 214812. request by Sherwin.					
					set ExcludeWafersArray(1) 1
					PutsDebug "LoadConfig: setting ExcludeWafersArray(1) to 1"
				}
			}
			PutsDebug "LoadConfig: reading $MOO block - Freq:$Info(freq) Stop:$Info(Stop_Die_Count) CPLEClass: $Info(CPLEClass), disablePrePMI:Info(disablePrePMI)  Exclude:$Info(Exclude_Wafers) ExtraTop:$Info(Extra_TopWafers) Extra:$Info(Extra_Wafers)"
		}		 
	}

   # update the limit to interface
	.buttonMenu.blank1 configure -text "$MOO\nFreq:$Info(freq) Stop:$Info(Stop_Die_Count)\n Exclude:$Info(Exclude_Wafers) ExtraTop:$Info(Extra_TopWafers) Extra:$Info(Extra_Wafers)"
	PutsDebug "LoadConfig: Freq:$Info(freq) Stop:$Info(Stop_Die_Count) CPLEClass: $Info(CPLEClass), disablePrePMI:Info(disablePrePMI)  Exclude:$Info(Exclude_Wafers) ExtraTop:$Info(Extra_TopWafers) Extra:$Info(Extra_Wafers)"
	WriteFile $LogFile "LoadConfig: Freq:$Info(freq) Stop:$Info(Stop_Die_Count) CPLEClass: $Info(CPLEClass), disablePrePMI:Info(disablePrePMI)  Exclude:$Info(Exclude_Wafers) ExtraTop:$Info(Extra_TopWafers) Extra:$Info(Extra_Wafers)"
}


###############################################################
# Get lot ID
###############################################################
proc SetupInfo {station wsize xsize ysize xref yref flat rotation yldhi yldlo lotid} {
	global Info
	set Info(LotID) $lotid
}

################################################################
# Get operator ID from integrator and output workload
################################################################

proc CellStatus { station cellID label operatorID waferID state deviceType lotName totalWafers lastWafer runningYield waferYield } {
	global Info env LogFile

	if { ! [ string equal $Info(operatorID) $operatorID ] } {
		set Info(operatorID) $operatorID
		set CURR_TIME [ clock format [ clock seconds ] -format "%Y%m%d%H%M%S" ]
		set logMsg [join [list $env(PROMIS_NAME) $CURR_TIME $operatorID $deviceType $Info(LotID) "" $Info(PassNumber) "SOL"] "_"]
		WriteFile $Info(WorkLoadLog) "$logMsg"
		PutsDebug "CellStatus: workload - $logMsg"
		#       exec touch $Info(WorkLoadDir)/$logMsg
		# change above command to below for catching exception. By Jiang Nan
		if { [ catch [eval exec touch $Info(WorkLoadDir)/$logMsg ] err ] } {
			WriteFile $LogFile "Error in execute touch $Info(WorkLoadDir)/$logMsg for $err"
		}
	}
	
	if {$state == "Wafer_end"} {
		set Info(isReprobe) 	 		 
	}	
}

###############################################################
#
#	startLot
#
###############################################################

proc StartOfLot {station} {

	global Info LogFile Debug_Flag fablot_lotinfo PROMISwaferList lastwaferID CumWaferNum opid_alert opid_pause opid_prechecking opid_pmichecking
	set Info(SOL) 1
	set ThisLotIsCorr 
	set Info(WaferCount) 
	set Info(FirstWafer) 1 
	set Info(TotalWaferCount) 1
	
	set Info(LotStartTimeStamp) [ clock seconds ]
	# init complete flag
	set Info(PMI_Complete) 
	updatePMIButton green " Lot is starting ... " " "
	
	
	set err_result [ catch { exec rm -f "$opid_alert" } result ]
	set err_result [ catch { exec rm -f "$opid_pause" } result ]
	set err_result [ catch { exec rm -f "$opid_prechecking" } result ]
	set err_result [ catch { exec rm -f "$opid_pmichecking" } result ]
	
#	WriteFile "$LogDir/pmi/pmi.out.zz" "$Info(HOST)"
	#
	# set No_PMI if LOT is not production lot
	#
	foreach pref $Info(NonProdLotPrefix) {
		set upperLotID [ string toupper $Info(LotID) ]
		set lotIDPattern "$pref\[-9\]\[-9\]\[-9\]\[-9\]\[-9\]*"
		if { [ string match $lotIDPattern $upperLotID ]  } {
			set Info(No_PMI) 1
			set ThisLotIsCorr 1
			WriteFile $LogFile "StartOfLot: LOT START: $upperLotID CORR LOT NO PMI."
			PutsDebug "StartOfLot: $upperLotID Non Production lot. Bypass PMI check.\n"
		} else {
			WriteFile $LogFile "StartOfLot: LOT START: $upperLotID "
			PutsDebug "StartOfLot: $upperLotID Production lot. \n"
		}
	}
	if { $ThisLotIsCorr ==  } {
		set manual_getlastwaferID 
		if [ file exists $fablot_lotinfo ] {			
			if { [ catch { set temp [eval exec grep $Info(LotID) $fablot_lotinfo ] } err ] } {
				PutsDebug "StartOfLot: grep $Info(LotID) $fablot_lotinfo ERROR. ERROR MSG: $err"
				WriteFile $LogFile "StartOfLot: grep $Info(LotID) $fablot_lotinfo ERROR. ERROR MSG: $err"
				set temp ""
			}
			set temp [ string trim $temp ]
			PutsDebug "StartOfLot: LOTINFO=$temp"
			set PROMISwaferList [ split [ lindex [ split $temp "," ] end ]   " " ]
			for {set i } {$i < [llength $PROMISwaferList] } {incr i 1} {
				set key [ lindex $PROMISwaferList $i ]
				if { $key == "" || ! [ string is integer $key ] } {
					PutsDebug "StartOfLot: PROMISwaferList($i)=|$key| -- value is not valid integer, remove from list"
					set PROMISwaferList [ lreplace $PROMISwaferList $i $i ]
				}
			}
			set PROMISwaferList [ lsort -integer $PROMISwaferList ]
			PutsDebug "StartOfLot: the finial list wafer ID list: $PROMISwaferList"
			set lastwaferID [ lindex $PROMISwaferList end ]
			set lastwaferID [ string trimleft $lastwaferID "" ]
			set lastwaferID [ string trim $lastwaferID ]
			if { [ string length $lastwaferID ] !=  && [ string is integer $lastwaferID ] && $lastwaferID <= 25 } {
				set manual_getlastwaferID 
				PutsDebug "StartOfLot: get lastwaferID from fablot_lotinfo. lastwaferID=$lastwaferID\n"
			} else {
				set manual_getlastwaferID 1
				PutsDebug "StartOfLot: get lastwaferID from fablot_lotinfo. lastwaferID=|$lastwaferID| . But format is wrong. Need manually input last Wafer ID. \n"
			}
		} else {
			set manual_getlastwaferID 1
			PutsDebug "StartOfLot: the fablot lotinfo file ($fablot_lotinfo) not exist.\n"
		}
		PutsDebug "StartOfLot: manual_getlastwaferID=$manual_getlastwaferID lastwaferID=$lastwaferID\n"
		if { $manual_getlastwaferID == 1 } {
		   showLastwaferIDWin $station
		}
	}
}


###############################################################
# Show LastwaferIDWin when select the last wafer ID
#
###############################################################

proc showLastwaferIDWin { station } {

    global Info BinDir LogFile lastwaferID .lastwaferID

	set lastwaferID "GETlastwaferIDFROMUI"
	PutsDebug "showLastwaferIDWin: reset lastwaferID=$lastwaferID"

	# stop integrator before get the lastwaferID
	# since integrator won't stop until first die. So remove this pause

	#  evr send pause $station


	# bring up the Interface to allow select wafer ID

	set screen ".lastwaferID"
	toplevel $screen
	wm geometry $screen "-3-4"
	wm deiconify $screen
	wm resizable $screen false false
	wm protocol $screen WM_DELETE_WINDOW { destroy $screen }
	wm title $screen "Input Last Wafer WaferID"

	tkwait visibility $screen
	focus -force $screen
	#grab set -global $screen

	label $screen.l -text "Please input last wafer ID:" -pady 2
	grid $screen.l -row 1 -column  -columnspan 5 -sticky w
	if { $station ==  } {
		button $screen.waf1 -text 1 -command { closeLastwaferIDWin 1  } -padx 15 -pady 15
		button $screen.waf2 -text 2 -command { closeLastwaferIDWin 2  } -padx 15 -pady 15
		button $screen.waf3 -text 3 -command { closeLastwaferIDWin 3  } -padx 15 -pady 15
		button $screen.waf4 -text 4 -command { closeLastwaferIDWin 4  } -padx 15 -pady 15
		button $screen.waf5 -text 5 -command { closeLastwaferIDWin 5  } -padx 15 -pady 15
		button $screen.waf6 -text 6 -command { closeLastwaferIDWin 6  } -padx 15 -pady 15
		button $screen.waf7 -text 7 -command { closeLastwaferIDWin 7  } -padx 15 -pady 15
		button $screen.waf8 -text 8 -command { closeLastwaferIDWin 8  } -padx 15 -pady 15
		button $screen.waf9 -text 9 -command { closeLastwaferIDWin 9  } -padx 15 -pady 15
		button $screen.waf1 -text 1 -command { closeLastwaferIDWin 1  } -padx 15 -pady 15
		button $screen.waf11 -text 11 -command { closeLastwaferIDWin 11  } -padx 15 -pady 15
		button $screen.waf12 -text 12 -command { closeLastwaferIDWin 12  } -padx 15 -pady 15
		button $screen.waf13 -text 13 -command { closeLastwaferIDWin 13  } -padx 15 -pady 15
		button $screen.waf14 -text 14 -command { closeLastwaferIDWin 14  } -padx 15 -pady 15
		button $screen.waf15 -text 15 -command { closeLastwaferIDWin 15  } -padx 15 -pady 15
		button $screen.waf16 -text 16 -command { closeLastwaferIDWin 16  } -padx 15 -pady 15
		button $screen.waf17 -text 17 -command { closeLastwaferIDWin 17  } -padx 15 -pady 15
		button $screen.waf18 -text 18 -command { closeLastwaferIDWin 18  } -padx 15 -pady 15
		button $screen.waf19 -text 19 -command { closeLastwaferIDWin 19  } -padx 15 -pady 15
		button $screen.waf2 -text 2 -command { closeLastwaferIDWin 2  } -padx 15 -pady 15
		button $screen.waf21 -text 21 -command { closeLastwaferIDWin 21  } -padx 15 -pady 15
		button $screen.waf22 -text 22 -command { closeLastwaferIDWin 22  } -padx 15 -pady 15
		button $screen.waf23 -text 23 -command { closeLastwaferIDWin 23  } -padx 15 -pady 15
		button $screen.waf24 -text 24 -command { closeLastwaferIDWin 24  } -padx 15 -pady 15
		button $screen.waf25 -text 25 -command { closeLastwaferIDWin 25  } -padx 15 -pady 15
	} elseif { $station == 1 }  {
		button $screen.waf1 -text 1 -command { closeLastwaferIDWin 1 1 } -padx 15 -pady 15
		button $screen.waf2 -text 2 -command { closeLastwaferIDWin 2 1 } -padx 15 -pady 15
		button $screen.waf3 -text 3 -command { closeLastwaferIDWin 3 1 } -padx 15 -pady 15
		button $screen.waf4 -text 4 -command { closeLastwaferIDWin 4 1 } -padx 15 -pady 15
		button $screen.waf5 -text 5 -command { closeLastwaferIDWin 5 1 } -padx 15 -pady 15
		button $screen.waf6 -text 6 -command { closeLastwaferIDWin 6 1 } -padx 15 -pady 15
		button $screen.waf7 -text 7 -command { closeLastwaferIDWin 7 1 } -padx 15 -pady 15
		button $screen.waf8 -text 8 -command { closeLastwaferIDWin 8 1 } -padx 15 -pady 15
		button $screen.waf9 -text 9 -command { closeLastwaferIDWin 9 1 } -padx 15 -pady 15
		button $screen.waf1 -text 1 -command { closeLastwaferIDWin 1 1 } -padx 15 -pady 15
		button $screen.waf11 -text 11 -command { closeLastwaferIDWin 11 1 } -padx 15 -pady 15
		button $screen.waf12 -text 12 -command { closeLastwaferIDWin 12 1 } -padx 15 -pady 15
		button $screen.waf13 -text 13 -command { closeLastwaferIDWin 13 1 } -padx 15 -pady 15
		button $screen.waf14 -text 14 -command { closeLastwaferIDWin 14 1 } -padx 15 -pady 15
		button $screen.waf15 -text 15 -command { closeLastwaferIDWin 15 1 } -padx 15 -pady 15
		button $screen.waf16 -text 16 -command { closeLastwaferIDWin 16 1 } -padx 15 -pady 15
		button $screen.waf17 -text 17 -command { closeLastwaferIDWin 17 1 } -padx 15 -pady 15
		button $screen.waf18 -text 18 -command { closeLastwaferIDWin 18 1 } -padx 15 -pady 15
		button $screen.waf19 -text 19 -command { closeLastwaferIDWin 19 1 } -padx 15 -pady 15
		button $screen.waf2 -text 2 -command { closeLastwaferIDWin 2 1 } -padx 15 -pady 15
		button $screen.waf21 -text 21 -command { closeLastwaferIDWin 21 1 } -padx 15 -pady 15
		button $screen.waf22 -text 22 -command { closeLastwaferIDWin 22 1 } -padx 15 -pady 15
		button $screen.waf23 -text 23 -command { closeLastwaferIDWin 23 1 } -padx 15 -pady 15
		button $screen.waf24 -text 24 -command { closeLastwaferIDWin 24 1 } -padx 15 -pady 15
		button $screen.waf25 -text 25 -command { closeLastwaferIDWin 25 1 } -padx 15 -pady 15
	} else {
		PutsDebug "LoadConfig: station is valid number. station = $station "
	}

	for {set i 1} {$i <=25} {incr i 1} {
		# button $screen.waf$i -text $i -command { set varn [ eval $i] ; PutsDebug $varn} -padx 15 -pady 15
		# PutsDebug "               button \$screen.waf$i -text $i -command \{ set lastwaferID $i; destroy $screen \} -padx 15 -pady 15"
		set rowid [ expr ($i - 1) / 5  + 3 ]
		set colid [ expr ($i - 1) % 5  ]
		grid $screen.waf$i -row $rowid -column $colid -sticky news
	}
}


###############################################################
# close LastwaferIDWin when select the last wafer ID
#
###############################################################
proc closeLastwaferIDWin { wafID  station } {
	global Info BinDir LogFile lastwaferID .lastwaferID

	set lastwaferID $wafID
	destroy .lastwaferID
	evr send start $station

	if {$lastwaferID != $Info(WaferID)} {
		set Info(doExtra) 
	}

	set d_time [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S"]
	PutsDebug "closeLastwaferIDWin: Manually input last wafer ID: $lastwaferID TIME: $d_time"
	WriteFile $LogFile "closeLastwaferIDWin: Manually input last wafer ID: $lastwaferID TIME: $d_time"

}


proc MoveCursor {station site x y}  {
	global Info
	if {$site == } {
		set Info(diex) $x
		set Info(diey) $y
	}
}

###############################################################
# At the end of each test (this gets called for each site) DO:
#
###############################################################
proc TestResults {station x y site test bin sort} {

	global Info BinDir BinDir LogFile Debug_Flag Debug_Flag_DieLevel BinLimitLog LOG_BIN opid_testcomplete

# add by JiangNan for bump
	if { $site == -1 } {
		return
	}
#end

# I don't know why we need add this?? so strange. JiangNan	
	if { $Info(SOL) ==  } {   
		PutsDebug "TestResults: The lot is end. Ignore follow TestResults events. "
		return  
	}

	incr Info(Tested)
	if { $Info(Tested) % 3 ==  } {
	   # touch the opid_testcomplete to show the integrator real status
		if { [ catch { exec $BinDir/sys_time -s > $opid_testcomplete } err  ]} {
			PutsDebug "TestResults: Can not touch opid_testcomplete: $opid_testcomplete, err = $err"
			WriteFile $LogFile "TestResults: Can not touch opid_testcomplete: $opid_testcomplete, err = $err"
		}
	}

	#set Info(diex) $x
	#set Info(diey) $y

	# add log at first die after PMI alert 
	if { $Info(PMI_Complete) == 1 } {
		set Info(PMI_Complete) 
		set wafer_num [string range $Info(WaferID) 2 end]
		
		set context " $Info(Device),$Info(LotID),w=$wafer_num,p=$Info(PassNumber),s=$Info(WaferCount), first die of PMI: diex=$Info(diex) diey=$Info(diey)"

		PutsDebug "TestResults: $context"
		WriteFile $LogFile "TestResults: After PMI Alert:$context"
	}

	if { [ info exists Info($station,$site,sitetested) ] }  {
		incr Info($station,$site,sitetested)
	} else {
		set Info($station,$site,sitetested) 1
	}

# I dont know why doing this, but seems only support single dut card.	
	if { $Info($station,$site,sitetested) > $Info($station,max,sitetested) } {
		set Info($station,max,sitetested) $Info($station,$site,sitetested)
	} else {
# ?? do not got why. Maybe he just want to avoid multi dut card? but why doing this way? --- JiangNan	
		set Info($station,$site,sitetested) $Info($station,max,sitetested)
		return
	}

	# Stop here if no PMI required
	if { $Info(No_PMI) == 1 } { return } 
	# Stop here if this wafer is in the excludewafers list
        # if doExtra is true, it will overwrite the exclude list
        # if it is FristWafer, it will overwrite the exclude list, FirstWafer is true only when at the beginning of 1st wafer

	if { $Info(ExcludeThisWafer) == 1 && $Info(doExtra) != 1 && $Info(FirstWafer) != 1 } {
            # if not setup "next n wafer PMI" from screen, return
		if { $Info(IntervalWaferCount) < $Info(IntervalValue) } {

		   # if wafer is excluded and it is on/beyond the limit now, counter reduce one, delay the trigger.
		   # to avoid next wafer stop at beginning of the wafer.

			if { $Info(WaferCount) >= $Info(freq) } {
				#set Info(WaferCount) [ incr Info(WaferCount) -1 ]
# I think it means if wafer#7 need do pmi, but we configured it as exclude, that makes us need to do pmi on wafer#8 not only skip wafer#7 and make next pmi on wafer#14				
				incr Info(WaferCount) -1
				return
			}
		}
	} 
#debug by JN
#	PutsDebug "\$Info(Common_PMI_Counter) = $Info(Common_PMI_Counter) \$Info(Flag) = $Info(Flag) \$Info(ABORTING) = $Info(ABORTING) \$Info(FirstWafer) = $Info(FirstWafer) \$Info(doExtraTop) = $Info(doExtraTop)"	

#

	if { $Info(Common_PMI_Counter) == 1 } { 

		# Added by JB 8/May/27, Added first wafer first die to stop
		if { $Info(FirstWafer) == 1 && $Info(Flag) ==  && $Info(ABORTING) ==  } {
			# first die of the lot
			if { $Info(PMI_Time) ==  } {
				set Info(PMI_Time) [ clock seconds ]
			}
			PutsDebug "TestResults: first wafer  pmi"
			doPMI $station $site
		}

		# Added by DJ 2985 , Added doExtra top wafer first die to stop
		if { $Info(doExtraTop) == 1 && $Info(Flag) ==  && $Info(ABORTING) ==  } {
			# first die of the wafer
			if { $Info(PMI_Time) ==  } {
				set Info(PMI_Time) [ clock seconds ]
			}
			PutsDebug "TestResults: extratop pmi"
			doPMI $station $site
		}

#		PutsDebug " TestResults: Info(doExtra) $Info(doExtra), Info(Tested) $Info(Tested), Info(TestableDie) $Info(TestableDie), Info(Stop_Die_Count) $Info(Stop_Die_Count) "
		if { $Info(doExtra) == 1 && ($Info(Tested) >= [ expr { $Info(TestableDie) - $Info(Stop_Die_Count)}]) } {
			if { $Info(PMI_Time) ==  } {
				set Info(PMI_Time) [ clock seconds ]
			}
			# Modified by JB 7/May/27
			PutsDebug "TestResults: extra pmi"
			doPMI $station	 $site
		} else {
			# General PMI case
			if { $Info(WaferCount) < $Info(freq) && $Info(WaferCount) >  && $Info(IntervalWaferCount) < $Info(IntervalValue) } { 
				# for wafer 1 - 6 since last PMI
				if { $Info(FirstWafer) == 1 && $Info(ExcludeThisWafer) != 1 && ($Info(Tested) >= [ expr { $Info(TestableDie) - $Info(Stop_Die_Count) } ] || $Info(WaferCount) > 1 ) } { 
					# first wafer of the lot
					if { $Info(PMI_Time) ==  } {
						set Info(PMI_Time) [ clock seconds ]
					}
					# Modified by JB 7/May/27
					PutsDebug "TestResults: first wafer no exclude pmi"
					PutsDebug "TestResults: $Info(doExtra),$Info(WaferCount),$Info(Stop_Wafer_Count),$Info(WaferCount),$Info(IntervalWaferCount),$Info(IntervalValue),$Info(FirstWafer),$Info(ExcludeThisWafer),$Info(Tested),$Info(TestableDie),$Info(Stop_Die_Count),$Info(WaferCount)"
# 1 2 6 2  999 1  9 86 5 2
					doPMI $station $site
				}  elseif { $Info(FirstWafer) == 1 && $Info(ExcludeThisWafer) == 1 }  {
#					set Info(FirstWafer) 
					set Info(WaferCount) 
				} 

			} else { 
				# for 12th wafer or more
				if { $Info(WaferCount) > $Info(freq) || $Info(IntervalWaferCount) > $Info(IntervalValue)} { 
					if { $Info(IntervalWaferCount) > $Info(IntervalValue) } {
						set Info(IntervalStopFlag) 1
					}
					if { $Info(WaferCount) > $Info(freq) } {
						set Info(NormalFlag) 1
					}
					# for 8th wafer or more
					if { $Info(PMI_Time) ==  } {
						set Info(PMI_Time) [ clock seconds ]
					}
					# Modified by JB 7/May/27
					PutsDebug "TestResults: wafercount > stop wafer count pmi"
					doPMI $station $site
				} else {
					if { ($Info(WaferCount) == $Info(freq) || $Info(IntervalWaferCount) == $Info(IntervalValue)) && $Info(Tested) >= [ expr { $Info(TestableDie) - $Info(Stop_Die_Count) } ] } {	
						if { $Info(IntervalWaferCount) == $Info(IntervalValue) } {
							set Info(IntervalStopFlag) 1
						}
						if { $Info(WaferCount) == $Info(freq) } {
							set Info(NormalFlag) 1
						}
						if { $Info(PMI_Time) ==  } {
							set Info(PMI_Time) [ clock seconds ]
						}
						# Modified by JB 7/May/27
						PutsDebug "TestResults: wafercount = Stop wafer count pmi"
						doPMI $station $site
					}
				}
			}
		}
	}
}


###############################################################
# At the start of each wafer DO:
#
###############################################################
proc StartOfWafer {station} {
	global Info BinDir BinDir LogFile Debug_Flag ExtraTopWafersArray ExtraWafersArray ExcludeWafersArray doExtra ExcludeThisWafer CumWaferNum
	global PROMISwaferList lastwaferID flag_autoCorrelation
	#set Info(WaferID) "m-1"
	set Info(ABORTING)  
	if { $flag_autoCorrelation == 1 } {
		set flag_autoCorrelation 
		set Info(cWaferID) "Corr"
	}
#	PutsDebug "cWaferID = $Info(cWaferID) WaferID = $Info(WaferID)"
	if { [string compare $Info(cWaferID) $Info(WaferID)] !=  } {
		set Info(cWaferID) $Info(WaferID)
		incr Info(WaferCount)
		incr CumWaferNum
# add by Jiang for jump CPLE auto-correlation wafer
		if {$CumWaferNum == } {
			return
		}
# end

		set Info(Common_PMI_Counter) 1
		
# add by Jiang Nan to make FirstWafer more robust....
		if {$CumWaferNum > 1 && $Info(FirstWafer) == 1} {
			set Info(FirstWafer) 
		}
# end
		
		if { $Info(IntervalFlag) == 1 } {
			incr {Info(IntervalWaferCount)}
		}		
	}

		# PutsDebug "1: $ExcludeWafersArray(1) "
		# PutsDebug "2: $ExcludeWafersArray(2) "
		# PutsDebug "3: $ExcludeWafersArray(3) "
		# PutsDebug "4: $ExcludeWafersArray(4) "
		# PutsDebug "7: $ExcludeWafersArray(7) "
		# PutsDebug "CumWaferNum: $CumWaferNum"

	if { $ExtraTopWafersArray($CumWaferNum) == 1 } {
		set Info(doExtraTop) 1
		set Info(Flag) 
		set ExtraTopWafersArray($CumWaferNum) 
	} else {
		set Info(doExtraTop) 
	}

	if { $ExtraWafersArray($CumWaferNum) == 1 } {
		set Info(doExtra) 1
	} else {
		set Info(doExtra) 
	}

	if { $ExcludeWafersArray($CumWaferNum) == 1 } {
		set Info(ExcludeThisWafer) 1
		PutsDebug "StartOfWafer: setting Info(ExcludeThisWafer) to 1"
	} else {
		set Info(ExcludeThisWafer) 
		PutsDebug "StartOfWafer: setting Info(ExcludeThisWafer) to "
	}


	# check wafer format, if wrong format, abort

	set searchresult [ string first "-" $Info(WaferID) ]
	if { $searchresult == 1 } {
		set tempStr [ string index $Info(WaferID)  ]
		if { $tempStr == 1 || $tempStr == 2 } {
			set tempStr [ string range $Info(WaferID) 2 end ]
			if { $tempStr != "" && [ string is integer $tempStr ] } {
				if { $tempStr > 25 } {
					PutsDebug "StartOfWafer: PMI ERROR: wafer ID passed from prober is not with correct format: $Info(WaferID) - greater than 25\n";
					abortlotfunc "Wrong Wafer ID detected"   $Info(WaferID) "pmi_abort.xbm"  $station
				} else {
					PutsDebug "StartOfWafer: wafer ID passed check: $Info(WaferID)  -- Seq No. $CumWaferNum - [clock format [ clock seconds ] -format "%Y-%m-%d %H:%M:%S"]\n"
				}
			} else {
				PutsDebug "StartOfWafer: PMI ERROR: wafer ID passed from prober is not with correct format: $Info(WaferID) - not integer after dash\n";
				abortlotfunc "Wrong Wafer ID detected"   $Info(WaferID) "pmi_abort.xbm"  $station
			}
		} else {
			PutsDebug "StartOfWafer: PMI ERROR: wafer ID passed from prober is not with correct format: $Info(WaferID) - wrong before dash\n"
			abortlotfunc "Wrong Wafer ID detected"   $Info(WaferID) "pmi_abort.xbm"  $station
		}
	} else {
		PutsDebug "StartOfWafer: PMI ERROR: wafer ID passed from prober is not with correct format: $Info(WaferID) - no dash\n"
		abortlotfunc "Wrong Wafer ID detected"   $Info(WaferID) "pmi_abort.xbm"  $station
	}

     # check if this wafer is the next wafer in PROMISwaferList

       # if Info(ThisWaferSeq) is still the initial value , give it first wafer sequence in PROMISwaferList

	if { [ llength $PROMISwaferList ] >  } {

		set Info(ThisWaferSeq) [ lsearch -exact $PROMISwaferList $tempStr ]

		if { $Info(ThisWaferSeq) == -1 } {
			PutsDebug "StartOfWafer:  This wafer($tempStr) is not in PROMISLIST. Abort the lot now\n"
			abortlotfunc "Wrong Wafer ID detected" "Wafer $tempStr not exist in PROMIS" "pmi_aborthold.xbm"  $station

		} else {
			PutsDebug "StartOfWafer:  This is wafer $tempStr. It is in PROMISLIST\n"
		}
	} else {
		PutsDebug "StartOfWafer:  Didn't get PROMISwaferList. llenght of PROMISwaferList is [ llength $PROMISwaferList ]"
	}


     # check if this is the last wafer, if yes, doExtra PMI

	if { [ string equal "GETlastwaferIDFROMUI" $lastwaferID ] || [ string equal $tempStr $lastwaferID ] } {
		PutsDebug "StartOfWafer: lastwaferID is $lastwaferID, tempStr = $tempStr, set doExtra 1"
		set Info(doExtra) 1
	}



	if { $Info(No_PMI) == 1 } {
		updatePMIButton grey " None PMI Device \n PMI Not Required!  " " "
		return
	}

	if { $Info(freq) == 1 } {
		updatePMIButton red " PMI Needed for Every Wafer! " "doPMI $station ask"
	} else {
		if { $Info(FirstWafer) == 1 } {
			updatePMIButton red " 1st Wafer of Lot \n PMI required " "doPMI	$station ask"
		} else {
			if [ file exists $Debug_Flag] {
				WriteFile $LogFile "Total Wafer Count: $Info(TotalWaferCount)"	
			}	
			foreach waf $Info(Extra_Wafers) {
				if [ file exists $Debug_Flag] {
					WriteFile $LogFile "Extra Wafer:$waf"
				}	
				if { $waf == $Info(TotalWaferCount) } {
					updatePMIButton red " Extra PMI Needed \n on This Wafer " "doPMI $station ask"
					set Info(doExtra) 1
				}
			}

			if { $Info(doExtra) == 1 } {
				updatePMIButton red " Do Extra PMI \n PMI required " "doPMI $station ask"
				return
			}

			if { $Info(WaferCount) < [ expr { $Info(freq) - 1 }] && $Info(IntervalWaferCount) < $Info(IntervalValue) } {
				updatePMIButton  green " $Info(WaferCount) Wafer(s) since last PMI " "askForPMI $station"
			} else {
				if { $Info(WaferCount) < $Info(freq) && $Info(IntervalWaferCount) < $Info(IntervalValue) } {
					updatePMIButton yellow " $Info(WaferCount) Wafer(s) since last PMI " "doPMI $station ask"
					PrePMI $station
				} else {
					if { $Info(WaferCount) == $Info(freq) && $Info(IntervalWaferCount) < $Info(IntervalValue) } {
						updatePMIButton red " $Info(WaferCount) Wafer(s) since last PMI \n PMI required " "doPMI $station" 
					} else { 
						updatePMIButton red " Wafer Limit Exceeded \n Do PMI Immediately! " "doPMI $station ask"
					}
				}
			}
		}
	}

	if { $Info(ExcludeThisWafer) == 1 && $Info(doExtra) != 1 } {
		updatePMIButton  green " $Info(WaferCount) Wafer(s) since last PMI\nThis wafer is excluded. " "askForPMI $station"
	} 
	
	updateAddPMIButton green " Additional Check " "AdditionalCheck $station"
}

proc ResetAll {station} {

	global Info ExtraTopWafersArray ExtraWafersArray ExcludeWafersArray CumWaferNum PROMISwaferList lastwaferID
	global flag4PMI_No_Button flag_autoCorrelation flag4PrePMI opid_alert opid_pause opid_prechecking opid_pmichecking
	# reset PMI_Complete
	set Info(PMI_Complete) 
	set Info(SOL) 
	set Info(WaferCount) 
	set Info(FirstWafer) 1
	set Info(ThisWaferSeq) -1
	set Info(Tested) 
	set Info(TestableDie) 
	set Info(cWaferID) N/A
	set Info(pWaferID) N/A
	set Info(PMI_Time) 
	set Info(PMI_START) 
	set Info(Common_PMI_Counter) 1
	set Info(Device) N/A
	set Info(LotID) "NotSetUp"
	set Info(WaferID) "1-"
	set Info(PassNumber) 
	set Info(No_PMI) 
	set Info(freq) 7
	set Info(Stop_Die_Count) 1
	set Info(disablePrePMI)  
	set Info(Extra_TopWafers) ""
	set Info(Extra_Wafers) ""
	set Info(Exclude_Wafers) ""
	set Info(doExtra) 
	set Info(TotalWaferCount) 
	set Info(Flag) 
	set Info(IntervalWaferCount) 
	set Info(IntervalValue) 999
	set Info(IntervalFlag) 
	set Info(IntervalStopFlag) 
	set Info(NormalFlag) 
	set Info(CPLEClass) "N/A"
	set Info(ABORTING)  
	set Info(NonProdLotPrefix) "C KK GG"
	set Info(LastPMIPauseDie) 1
	set Info($station,max,sitetested) 
	set Info(operatorID) ""
	# add by JiangNan for TTT status
	set Info(isReprobe) 
	set Info(PCID) NA
	set Info(PCType) 
	# end
	# add by JiangNan for combine pmi wait & pmi do
	set Info(PMI_DELAY) 
	set Info(PrePMI2PMI) 
	# end
	set Info(ASKPMI) ""
	set flag4PMI_No_Button 
	set flag_autoCorrelation 
	set flag4PrePMI 

	set Info(diex) 
	set Info(diey) 

	set CumWaferNum 
	set PROMISwaferList {}
	set lastwaferID ""

	for { set i } { $i <=25 } { incr i } {
		set ExtraTopWafersArray($i) 
		set ExtraWafersArray($i) 
		set ExcludeWafersArray($i) 
	}
	set ExcludeWafersArray(1) 1
	
	set err_result [ catch { exec rm -f "$opid_alert" } result ]
	set err_result [ catch { exec rm -f "$opid_pause" } result ]
	set err_result [ catch { exec rm -f "$opid_prechecking" } result ]
	set err_result [ catch { exec rm -f "$opid_pmichecking" } result ]
}


###############################################################
# WaferInfo:  this provides information about the current wafer
# - we used testable die
###############################################################
proc WaferInfo {station wafer_id passnumber subpass xrefoffset yrefoffset yield testable zwindow} {

	global Info LogFile BinDir BinDir Debug_Flag

	set Info(WaferID) "$wafer_id"
	set Info(RFile) "r_$wafer_id"
	set Info(TestableDie) $testable
	set Info(PassNumber) $passnumber

	if [file exists $Debug_Flag] {		
		WriteFile $LogFile "WaferInfo: testable dies $Info(TestableDie)"
		WriteFile $LogFile "WaferInfo: new WaferID: $Info(WaferID) old WaferID: $Info(cWaferID)"
	}
}

###############################################################
# End of Wafer
# Called on A5s
# Part of automatic OCAP's:
# This will take care of the N/M wafers below the scrap limit,
# opens, and current wafer below the scrap limit.
#
###############################################################
proc EndOfWafer {station wafer_id cassette slot num_pass num_tested start_time end_time lot_id} {

	global Info env LogFile BinDir BinDir 
	global opid_testcomplete
	global flag4PrePMI
	if {$flag4PrePMI == 1} {
		set flag4PrePMI 2
	}

	set err_result [ catch { exec rm -f "$opid_testcomplete" } result ]


	set Info(Tested) 
	set Info($station,max,sitetested) 
	set Info(LastPMIPauseDie) -1

	set Info(diex) 
	set Info(diey) 

	foreach value [ array names Info "*,sitetested" ] {
		set Info($value) 
	}

	WriteFile $LogFile "EndOfWafer: Wafer - $Info(WaferID) pWafer - $Info(pWaferID)"
	
	if { [string compare $Info(pWaferID) $Info(WaferID)] !=  } {
		incr Info(TotalWaferCount)
		WriteFile $LogFile "EndOfWafer: Total Wafer: $Info(TotalWaferCount)"	
		set Info(pWaferID) $Info(WaferID)
	}

	# update the StationOwner
	updateStationOwner 
}

###############################################################
# End of Wafer for catalyst testers
###############################################################

#proc EndOfWafer_2 {station wafer_id cassette slot num_pass num_tested start_time end_time lot_id} {
#	global Info env LogFile BinDir BinDir Debug_Flag
#	EndOfWafer $station
#}

###############################################################
#
# WriteFile
#
###############################################################
proc WriteFile { filename text } {
	set time_stamp [clock format [clock seconds] -format "%D %T"]
	set fp [open $filename "a+"]
	puts $fp "$text <= @ $time_stamp"
	close $fp
}

###############################################################
#
# Debug Output
#
###############################################################

proc PutsDebug {context} {
	global Debug_Flag
	if [ catch { set time [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S" ] } ] {
		set time N/A
	}
	if [ file exists $Debug_Flag ] {
		puts "$context -- $time"
	}
}

###############################################################
#                                                             #
# Update PMI indicator Color and Wafer Counter                #
#                                                             #
###############################################################
proc updatePMIButton {color text cmd} {
	if { ![winfo exists .buttonMenu.pmi ]} {
		return	
	}
	.buttonMenu.pmi configure -bg $color -text $text -command $cmd
}

###############################################################
#                                                             #
# Update PMI indicator Color and Wafer Counter                #
#                                                             #
###############################################################
proc updateAddPMIButton {color text cmd} {
	if { ![winfo exists .buttonMenu.addpmi ]} {
		return	
	}
	.buttonMenu.addpmi configure -bg $color -text $text -command $cmd
}

###############################################################
#                                                             #
# check ERROR                                                 #
#                                                             #
###############################################################
proc checkERRORmsg { errmsg station } {
	if { [ string equal $errmsg "couldn't create pipe: too many open files" ] } {
	   genabortlotfunc "SUN System Error"   "Meet system error and PMI program can not continue. Please reboot SUN station!!!"  ""  $station
	}
}

###############################################################
#                                                             #
# create abort dialog                                         #
#                                                             #
###############################################################
proc abortlotfunc {title text xbmfile station} {
	global Info BinDir BinDir Debug_Flag LogFile
	global .pre_pmi_option .do_pmi
	global opid_alert opid_pause opid_prechecking opid_pmichecking

	set Info(ABORTING)  1

	evr send pause $station

	if { [winfo exists .pre_pmi_option] } {
		destroy .pre_pmi_option
	}

	if { [winfo exists .do_pmi] } {
		destroy .do_pmi
	}

	set answer [ tk_dialog .abortlotfunc $title "" @$BinDir/$xbmfile  "    WaferID is not correct: $text     Click to ABORT LOT         " ]

	if { $answer ==  } {

		set err_result [ catch { exec rm -f "$opid_alert" } result ]
		set err_result [ catch { exec rm -f "$opid_pause" } result ]
		set err_result [ catch { exec rm -f "$opid_prechecking" } result ]
		set err_result [ catch { exec rm -f "$opid_pmichecking" } result ]

		evr send abortlot -discard $station
		evr send start $station

	}
}

proc genabortlotfunc {title text xbmfile station} {
	global Info BinDir BinDir Debug_Flag LogFile
	global .pre_pmi_option .do_pmi
	global opid_alert opid_pause opid_prechecking opid_pmichecking

	set outmsg "genabortlotfunc: critical error. Pop up ABORT-LOT window. Waiting for respond.....  [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"]"

	PutsDebug $outmsg
	WriteFile $LogFile $outmsg

	set Info(ABORTING)  1

	evr send pause $station

	if { [winfo exists .pre_pmi_option] } {
		destroy .pre_pmi_option
	}

	if { [winfo exists .do_pmi] } {
		destroy .do_pmi
	}

	set answer [ tk_dialog .abortlotfunc $title $text $xbmfile        "  Click to ABORT LOT " ]

	if { $answer ==  } {

		set err_result [ catch { exec rm -f "$opid_alert" } result ]
		set err_result [ catch { exec rm -f "$opid_pause" } result ]
		set err_result [ catch { exec rm -f "$opid_prechecking" } result ]
		set err_result [ catch { exec rm -f "$opid_pmichecking" } result ]

		evr send abortlot -discard $station
		evr send start $station

		set outmsg "genabortlotfunc: aborting lot ..... [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"]"

		PutsDebug $outmsg
		WriteFile $LogFile $outmsg

	}
}


###############################################################
# Optional PMI dialog                                         #
###############################################################
proc askForPMI {station} {
	global Info
	if { [winfo exists .pmi_option] } {
		return
	}

	set msg "This is not the scheduled time for Probe Mark Inspection! \nDo you still want to perform PMI?\n"
	set answer [ tk_dialog .pmi_option "PMI Message" $msg warning  "Yes, perform a PMI NOW" "No, continue probing until it's due" ]
	if { $answer ==  } {
		set Info($station,ask,sitetested) $Info($station,max,sitetested)
		incr Info($station,ask,sitetested)
		PutsDebug "askForPMI: ask pmi"
		doPMI $station "ask"
		set Info(ASKPMI) "1"
	} 
}

###############################################################
# Pre PMI dialog, Created by JB 2/July/27                   #
###############################################################
proc PrePMI {station} {
	global Info BinDir BinDir Debug_Flag LogFile
	global .pre_pmi_option pre_flag pre_checking
	global opid_alert opid_pause opid_prechecking opid_pmichecking
	global flag4PrePMI
	

	if { $Info(disablePrePMI) == 1 } {
		PutsDebug "PrePMI: This device has disabled Pre-PMI."
		return
	}

	set pre_flag 
	set pre_checking 

	set err_result [ catch { exec rm -f "$opid_prechecking" } result ]
	set err_result [ catch { exec rm -f "$opid_pmichecking" } result ]
	set err_result [ catch { exec rm -f "$opid_pause" } result ]
	set err_result [ catch { exec touch "$opid_alert" } result ]


	if { [winfo exists .pre_pmi_option] } {
		PutsDebug "PrePMI: Pre-PMI window exist. Do nothing."
		return
	}
	
	
	set msg "PrePMI: Pre-PMI window starting now ....die:$Info(Tested) touch:$Info($station,max,sitetested) last:$Info(LastPMIPauseDie) - [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"]\n"
	PutsDebug $msg
	WriteFile $LogFile $msg
	set flag4PrePMI 1
	set msg "There 1 wafer to the scheduled time for Probe Mark Inspection! \n\n\nDo you want to perform PMI?\n"
	set answer [ tk_dialog .pre_pmi_option "PMI Message" $msg @$BinDir/pre_pmi_bitmap  "Yes, perform a PMI NOW" "No, continue probing until it's due" ]
	if { $answer ==  && $pre_flag ==  } {
		set msg "PrePMI: Pre-PMI to PMI ....die:$Info(Tested) touch:$Info($station,max,sitetested) last:$Info(LastPMIPauseDie) - [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"]\n"
		set Info(PrePMI2PMI) 1
		PutsDebug $msg
		WriteFile $LogFile $msg
		set Info($station,ask,sitetested) $Info($station,max,sitetested)
		incr Info($station,ask,sitetested)
        # modified by tantan 21-4-2 for prepmichecking show on floorview #
        set pre_checking 1
        set err_result [ catch { exec rm -f "$opid_alert" } result ]
        set err_result [ catch { exec touch "$opid_prechecking" } result ]
		doPMI $station "ask"
		set Info(ASKPMI) ""
	} elseif { $answer == 1 && $pre_flag ==  } {
		set name ""
		set password ""
		set Confirmed "failed"
		set flag4PrePMI -1
		Login_Screen .login_menu "Delay_PrePMI" $station
	}

	set err_result [ catch { exec rm -f "$opid_alert" } result ]
	
}


###############################################################
# Instruction for PMI                                         #
# look here    by J.N                                         #
###############################################################
proc doPMI {station site} {
	global Info BinDir BinDir Debug_Flag Debug_Flag_DieLevel LogFile
	global .pre_pmi_option pre_flag pre_checking
	global opid_alert opid_pause opid_prechecking opid_pmichecking
	global Confirmed name password
	global site_trigger flag4PMI_No_Button
	set site_trigger $site

	if { $Info(SOL) ==  } {   
		PutsDebug "doPMI: The lot is end. Ignore follow doPMI events."
		return  
	}

	if { [winfo exists .shresult_PMI ] } {
		PutsDebug "doPMI: .shresult_PMI window exist. Performing PMI. Ignore follow doPMI events."
		return
	}


	set msg "doPMI: enter doPMI .... site:$site die:$Info(Tested) touch:$Info($station,max,sitetested) last:$Info(LastPMIPauseDie) - [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"]\n"
	PutsDebug $msg
	WriteFile $LogFile $msg

        # modified by tantan 21-4-2 for prepmichecking show on floorview #  
	if { $pre_checking ==  } {
		set err_result [ catch { exec rm -f "$opid_alert" } result ]
		set err_result [ catch { exec rm -f "$opid_prechecking" } result ]
		set err_result [ catch { exec rm -f "$opid_pmichecking" } result ]
		set err_resulr [ catch { exec touch "$opid_pause" } result ]
	}	

	# Modified by Daniel Jin 28.1.22 for excced_dies from 1 to 3
        # Modified by Daniel Jin 28.11.24 for excced_dies from 1 to 16
		
	set exceed_dies [ expr $Info($station,max,sitetested) - $Info(LastPMIPauseDie) ]
	
	if { $exceed_dies >=1 && $exceed_dies <=16 } {
#		 if { [ file exists $Debug_Flag_DieLevel ] } {
#			# output debug information to log file
#			set debug_msg "doPMI: check if in torlerant range -> between 1 to 3, return. exceed_dies = $exceed_dies"
#			PutsDebug $debug_msg
#			WriteFile $LogFile $debug_msg
#		 }
		PutsDebug "doPMI: doPMI torlerant....die:$Info(Tested) touch:$Info($station,max,sitetested) last:$Info(LastPMIPauseDie) - [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"]\n"
#mark : this is changed by JN for click No button on PMI login fail window
		if { $flag4PMI_No_Button == } {
			return
		} elseif { $flag4PMI_No_Button ==1 } {
			set flag4PMI_No_Button 
		} else {
			PutsDebug "doPMI : Torlerant part ERROR , quickly check it!!"
		}
	} else {
		set Info(LastPMIPauseDie) $Info($station,max,sitetested)
#		if { [ file exists $Debug_Flag_DieLevel ] } {
#			# output debug information to log file
#			set debug_msg "doPMI: check if in torlerant range -> out of 1 to 3, continue. exceed_dies = $exceed_dies"
#			PutsDebug $debug_msg
#			WriteFile $LogFile $debug_msg
#		}
		PutsDebug "doPMI: doPMI send pause....die:$Info(Tested) touch:$Info($station,max,sitetested) last:$Info(LastPMIPauseDie) - [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"]\n"
		evr send pause -alarm $station
	}

	if { [winfo exists .do_pmi] } {
		PutsDebug "doPMI: doPMI window exist. Destory it now."
		PutsDebug "          WaferCount: $Info(WaferCount) die:$Info(Tested) touch:$Info($station,max,sitetested) last:$Info(LastPMIPauseDie) - [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"]\n"
		destroy .do_pmi
	}

	if { [winfo exists .login_menu ] } {
		PutsDebug "doPMI: doPMI login window exist. Destory it now."
		PutsDebug "          WaferCount: $Info(WaferCount) die:$Info(Tested) touch:$Info($station,max,sitetested) last:$Info(LastPMIPauseDie) - [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"]\n"
			destroy .login_menu
	}

	if { [winfo exists .shresult ] } {
		PutsDebug "doPMI: doPMI login .shresult window exist. Destory it now."
		PutsDebug "          WaferCount: $Info(WaferCount) die:$Info(Tested) touch:$Info($station,max,sitetested) last:$Info(LastPMIPauseDie) - [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"]\n"
			destroy .shresult
	}

	if { [winfo exists .pre_pmi_option] } {
		PutsDebug "doPMI: doPMI Pre-PMI window exist. Destory it now."
		PutsDebug "          WaferCount: $Info(WaferCount) die:$Info(Tested) touch:$Info($station,max,sitetested) last:$Info(LastPMIPauseDie) - [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"]\n"
		destroy .pre_pmi_option
		set pre_flag 1
	}

	if [file exists $Debug_Flag] {
		WriteFile $LogFile "doPMI -- WaferCount: $Info(WaferCount) FirstWafer: $Info(FirstWafer)"
	}

	if { $Info(PMI_Time) ==  } {
		set Info(PMI_Time) [ clock seconds ]
	}
	
	# commented by JB 7/May/27
	#set cmd "$BinDir/AutoOCAPs/pauseTime Wafer Inspection,$Info(Device),$Info(LotID),$Info(WaferCount),$Info(RFile),PMI Flag's Up"
	#eval exec $cmd

       ## with evr send pause -alarm $station, enable operator to check PMI first and then click on the interface and remove 
       ## the screen.
	# set msg "Please resume Integrator, pause the prober to perform PMI.\n\n\nAfter PMI is completed, resume the prober and click OK.\n\n"
	set msg "PAUSE TIME: [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"]\n"
	set msg "$msg\n\nPlease check Probe Mark on prober and then resume Integrator"

	after 6 



        # make sure .lastwaferID screen always on the top
	if { [winfo exists .lastwaferID] } {
		destroy .lastwaferID
		showLastwaferIDWin $station
	}

	PutsDebug "doPMI: need check PMI now. PMI window will show up die:$Info(Tested) touch:$Info($station,max,sitetested) last:$Info(LastPMIPauseDie) [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"]\n"

	set Info(PMI_Time) [ clock seconds ]

	set d_time [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S"]
	set wafer_num [string range $Info(WaferID) 2 end]
	set context "$d_time,$Info(Device),$Info(LotID),$wafer_num,$Info(PassNumber),$Info(WaferCount) - PMI showup $Info(Tested)"

	set Info(PMI_Complete) 1

	if { $Info(FirstWafer) == 1 || $Info(WaferCount) == $Info(freq) } {
		if { $Info(Tested) >= [ expr { $Info(TestableDie) - $Info(Stop_Die_Count) } ] } {
			# Modified by JB 23/May/27
			#set answer [ tk_dialog .do_pmi "PMI Message" $msg info  "OK" ]
			set answer [ tk_dialog .do_pmi "PMI Message" $msg @$BinDir/pmi_bitmap  "OK" ]
			WriteFile $LogFile "doPMI: $context"
                        
		} else {
			if { $Info(FirstWafer) == 1 && $Info(WaferCount) > 1 } {
				# Modified by JB 23/May/27
				#set answer [ tk_dialog .do_pmi "PMI Message" $msg info  "OK" ]
				set answer [ tk_dialog .do_pmi "PMI Message" $msg @$BinDir/pmi_bitmap  "OK" ]
				WriteFile $LogFile "doPMI: $context"
			} else {
				# Modified by JB 8/May/27
				#set answer [ tk_dialog .do_pmi "PMI Message" $msg info  "OK" ]
				# Modified by JB 23/May/27
				set answer [ tk_dialog .do_pmi "PMI Message" $msg @$BinDir/pmi_bitmap  "OK" ]
				WriteFile $LogFile "doPMI: $context"
			}
		}
	} else {
		if {$Info(WaferCount) > $Info(freq) } {
			# Modified by JB 23/May/27
			#set answer [ tk_dialog .do_pmi "PMI Message" $msg info  "OK" ]
			set answer [ tk_dialog .do_pmi "PMI Message" $msg @$BinDir/pmi_bitmap  "OK" ]
			WriteFile $LogFile "doPMI: $context"
		} else {
			# Will popup windiw when $Info(IntervalWaferCount) >= $Info(IntervalValue)
			# Modified by JB 23/May/27
			#set answer [ tk_dialog .do_pmi "PMI Message" $msg info  "OK" "Cancel"]
			set answer [ tk_dialog .do_pmi "PMI Message" $msg @$BinDir/pmi_bitmap  "OK" ]
			WriteFile $LogFile "doPMI: $context"
		}
	}


	set Site na
	set Limit none
	set Faliure none
	set Type PMI

	if { $answer ==  } {

		set name ""
		set password ""
		set Confirmed "failed"

		Login_Screen .login_menu "Proceed_Probe" $station
		

	}
}

####################################################################
# Additional PMI Check, Created by JB 19/Mar/28                  #
####################################################################
proc AdditionalCheck {station} {
	
	global name password Confirmed
	
	set name ""
	set password ""
	set Confirmed "failed"

	Login_Screen .login_menu  "AdditionalCheckContinue" $station
}

proc AdditionalCheckContinue {station} {
       
	global .prompt Value Confirmed
	global Info BinDir BinDir LOG_BIN LogFile

	
	set wafer_num [string range $Info(WaferID) 2 end]
	set d_time [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S"]
	
	if { [winfo exists .prompt] } {
		return
	}
	
	set f .prompt
	set Value 1
	
	wm withdraw .
	wm geometry . {}
	
	toplevel $f -borderwidth 1
	wm geometry $f "-3-4"
	wm deiconify $f
	wm resizable $f false false
	wm protocol $f WM_DELETE_WINDOW { destroy $screen }
	wm title $f "Prompt"
	
	tkwait visibility $f
	focus -force $f
	#grab set -global $f
		
	set ft [frame $f.top]
	set fb [frame $f.bottom]
	
	message $ft.msg -text "Please enter interval value" -aspect 1
	entry $fb.entry -textvariable Value -width 5 -state disable
	menubutton $fb.mb -bitmap @$BinDir/dropdown_bitmap -menu $fb.mb.menu -relief raised 
	set b [frame $f.buttons]
	pack $ft $fb
	pack $ft.msg 
	pack $fb.entry $fb.mb -side left
	pack $f.buttons -side top -fill x
	pack $fb.entry -pady 1
	
	set m [menu $fb.mb.menu -tearoff 1]

	$m add command -label 1 -command {set Value 1}
	$m add command -label 2 -command {set Value 2}
	$m add command -label 3 -command {set Value 3}
	$m add command -label 4 -command {set Value 4}
	$m add command -label 5 -command {set Value 5}
#	$m add command -label 6 -command {set Value 6}
#	$m add command -label 7 -command {set Value 7}
#	$m add command -label 8 -command {set Value 8}
#	$m add command -label 9 -command {set Value 9}
#	$m add command -label 1 -command {set Value 1}
#	$m add command -label 11 -command {set Value 11}
#	$m add command -label 12 -command {set Value 12}
#	$m add command -label 13 -command {set Value 13}
#	$m add command -label 14 -command {set Value 14}
#	$m add command -label 15 -command {set Value 15}
#	$m add command -label 16 -command {set Value 16}
#	$m add command -label 17 -command {set Value 17}
#	$m add command -label 18 -command {set Value 18}
#	$m add command -label 19 -command {set Value 19}
#	$m add command -label 2 -command {set Value 2}
#	$m add command -label 21 -command {set Value 21}
#	$m add command -label 22 -command {set Value 22}
#	$m add command -label 23 -command {set Value 23}
#	$m add command -label 24 -command {set Value 24}
		
	button $b.ok -text OK -command { 		
		set Info(IntervalValue) $Value
		set Info(IntervalFlag) 1
		set context "$Info(Device),$d_time,$Confirmed,$Info(LotID),$wafer_num,$Info(PassNumber),$Info(WaferCount),$Info(IntervalValue)"
		WriteFile $LogFile "AdditionalCheck: $context"
		
		destroy .prompt
	}
	button $b.cancel -text Cancel -command { 
		destroy .prompt
	}
	pack $b.ok -side left -pady 5
	pack $b.cancel -side right -pady 5
	
	focus $b.ok
	
}
	
###############################################################
# PMI Pause Logger
# User authentication use .X5 login/password
# Record necessary information for the event
#      MOO, Event Type, Limit, Trigger/Bin
#      Responce, Host, Date/Time, Delay, Responder
#      Lot, Wafer, Pass, PCID, PIB, Pogo Stack  
###############################################################
proc Proceed_Probe {station} {
	global Info BinDir BinDir LOG_BIN LogFile wafer_num d_time env flag4PrePMI RecordFile
	global opid_name Confirmed opid_alert opid_pause opid_prechecking opid_pmichecking


  # Out Work Load Information
	if { ! [ string equal $Info(ASKPMI) "1" ] } {
		set CURR_TIME [ clock format [ clock seconds ] -format "%Y%m%d%H%M%S"]
		if [ catch { set waferID [ format "%2d" [lindex [ split $Info(WaferID) "-" ] 1] ] } ]  {
			set waferID "NoWaferIDAssigned"
		} 
		set logMsg [join [list $env(PROMIS_NAME) $CURR_TIME [string toupper $Confirmed] $Info(Device) $Info(LotID) $waferID $Info(PassNumber) "PMI"] "_"]
		WriteFile $Info(WorkLoadLog) "$logMsg"
		PutsDebug "Proceed_Probe: workload - $logMsg"
#		exec touch $Info(WorkLoadDir)/$logMsg
# change above command to below for catching exception. By Jiang Nan
		if { [ catch [eval exec touch $Info(WorkLoadDir)/$logMsg ] err ] } {
			WriteFile $LogFile "Proceed_Probe: Error in execute touch $Info(WorkLoadDir)/$logMsg for $err"
		} else {
	
		}
	}
	set Info(ASKPMI) ""


	# create the flag file for operator name

	PutsDebug "Proceed_Probe: user $Confirmed checked PMI. touch opid_name echo $Confirmed > $opid_name diex=$Info(diex) diey=$Info(diey)"
	set err_result [ catch { exec echo $Confirmed > $opid_name  } result ]

	#set d_time [eval exec "$BinDir/sys_time -t" ]
	#set delay [eval exec "$BinDir/cal_delay $Info(PMI_START) ]

	set d_time [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S"]

	set delay_min [ expr ( [ clock seconds ] - $Info(PMI_START) ) / 6  ]
	set delay_sec [ expr  [ clock seconds ] - $Info(PMI_START) - $delay_min * 6 ]
	set delay "PMI $delay_min min $delay_sec sec"

	set wafer_num [string range $Info(WaferID) 2 end]

	set context "$d_time,$Info(Device),$delay,$Confirmed,$Info(LotID),w=$wafer_num,p=$Info(PassNumber),s=$Info(WaferCount) diex=$Info(diex) diey=$Info(diey)"
	
	PutsDebug "Proceed_Probe: $context"
	WriteFile $LogFile "Proceed_Probe: $context"
	
	set delay_tmp [ expr  [ clock seconds ] - $Info(PMI_START)]
	set context "PMI DO:$Info(HOST),$Info(Device),$Info(LotID),$Info(PassNumber),$Info(WaferID),$Info(PCID),$Info(Total_Site),$Info(diex),$Info(diey),$Info(PrePMI2PMI),$Confirmed,$Info(PMI_DELAY),$delay_tmp"
	WriteFile $RecordFile "$context"

	set Info(PrePMI2PMI) 
	set Info(PMI_DELAY) 

	set err_result [ catch { exec rm -f "$opid_alert" } result ]
	set err_result [ catch { exec rm -f "$opid_pause" } result ]
	set err_result [ catch { exec rm -f "$opid_prechecking" } result ] 
	set err_result [ catch { exec rm -f "$opid_pmichecking" } result ] 


	# Added Info(Flag) by JB 8/May/27
	if { $Info(Flag) ==  } {
		set Info(Flag) 1	
	} else {
		if { $Info(IntervalStopFlag) == 1 } {
			set Info(IntervalStopFlag) 
			set Info(IntervalWaferCount) 
			set Info(IntervalValue) 999
			set Info(IntervalFlag) 
			set Info(PMI_Time) 
			set Info(PMI_START) 
			updatePMIButton green " Done additional PMI check " "askForPMI $station"
			if { $Info(NormalFlag) == 1 } {
				set Info(Common_PMI_Counter) [expr {$Info(Common_PMI_Counter) - 1}]
				updatePMIButton green "  Wafer(s) since last PMI " "askForPMI $station"
	
				# Commented by JB 7/May/27
				#set cmd "$BinDir/AutoOCAPs/pauseTime Wafer Inspection,$Info(Device),$Info(LotID),$Info(WaferCount),$Info(RFile),PMI Completed"
				#eval exec $cmd
				if {$flag4PrePMI == 1} {
					PutsDebug "Proceed_Probe: setting wafercount to -1, flag4PrePMI = $flag4PrePMI"
					set Info(WaferCount) -1
				} else {
					PutsDebug "Proceed_Probe: setting wafercount to , flag4PrePMI = $flag4PrePMI"
					set Info(WaferCount) 
				}
				set $flag4PrePMI 3
				if { $Info(FirstWafer) == 1 } {
					set Info(FirstWafer) 
				}	
				set Info(PMI_Time) 
				set Info(PMI_START) 
				if { $Info(doExtra) == 1 } { set Info(doExtra)  }
			}
		} else {				
		
			set Info(Common_PMI_Counter) [expr {$Info(Common_PMI_Counter) - 1}]
			updatePMIButton green "  Wafer(s) since last PMI " "askForPMI $station"
			
			# Commented by JB 7/May/27
			#set cmd "$BinDir/AutoOCAPs/pauseTime Wafer Inspection,$Info(Device),$Info(LotID),$Info(WaferCount),$Info(RFile),PMI Completed"
			#eval exec $cmd
			if {$flag4PrePMI == 1} {
				PutsDebug "Proceed_Probe: setting wafercount to -1, flag4PrePMI = $flag4PrePMI"
				set Info(WaferCount) -1
			} else {
				PutsDebug "Proceed_Probe: setting wafercount to , flag4PrePMI = $flag4PrePMI"
				set Info(WaferCount) 
			}
			set $flag4PrePMI 3
			if { $Info(FirstWafer) == 1 } {
				set Info(FirstWafer) 
			}	
			set Info(PMI_Time) 
			set Info(PMI_START) 
			if { $Info(doExtra) == 1 } { set Info(doExtra)  }
		}
	}
	evr send start $station
}

###############################################################
# Status Message
###############################################################
proc StatusMsg {station message} {
	PutsDebug "StatusMsg: $message"
}

proc ProbeCardDefine { station card_id card_type dib_id dib_type args } {
	global Info
	set Info(PCID) [ string tolower $card_id ]
	
	set Info(Total_Site) 
	foreach location $args {
		incr Info(Total_Site)
	}
}

proc evrprobecardevent { station tyPerfEvent npolish ntouch pcID pcType sites[]} {
	global Info env promisname
	#set Info(NumPolish) $npolish
	set Info(PcType) $pcType
	set Info(PCID) $pcID
	#set Info(NTouch) $ntouch
	
}

proc EndOfLot {station} {

	global .pre_pmi_option .do_pmi Confirmed Info env RecordFile
	global opid_alert opid_pause opid_testcomplete opid_prechecking opid_pmichecking 

	set Info(LotEndTimeStamp) [ clock seconds ]
	set delay_tmp [expr $Info(LotEndTimeStamp) - $Info(LotStartTimeStamp)]
	WriteFile $RecordFile "Lot End:$Info(HOST),$Info(Device),$Info(LotID),$Info(PassNumber),$Info(PCID),$Info(Total_Site),$Info(LotEndTimeStamp),$Info(LotStartTimeStamp),$delay_tmp"
	
	# Out Work Load Information
	set CURR_TIME [ clock format [ clock seconds ] -format "%Y%m%d%H%M%S"]
	if [ catch { set waferID [ format "%2d" [lindex [ split $Info(WaferID) "-" ] 1] ] } ]  {
		set waferID "NoWaferIDAssigned"
	} 
	set logMsg [join [list $env(PROMIS_NAME) $CURR_TIME [string toupper $Confirmed] $Info(Device) $Info(LotID) $waferID $Info(PassNumber) "EOL"] "_"]
	WriteFile $Info(WorkLoadLog) "$logMsg"
	PutsDebug "EndOfLot: workload - $logMsg"

	set Info(SOL) 
	ResetAll $station
	if { [winfo exists .pre_pmi_option] } {
		destroy .pre_pmi_option
	}

	if { [winfo exists .do_pmi] } {
		destroy .do_pmi
	}

	if { [winfo exists .login_menu] } {
		destroy .login_menu
	}

	if { [winfo exists .login_menu_patrol] } {
		destroy .login_menu_patrol
	}

	if { [winfo exists .shresult_PMI] } {
                destroy .shresult_PMI
        }	

	
	updatePMIButton green " Lot has not started yet " " "
	updateAddPMIButton red " Additional Check " " "

	set err_result [ catch { exec rm -f "$opid_alert" } result ]
	set err_result [ catch { exec rm -f "$opid_pause" } result ]
	set err_result [ catch { exec rm -f "$opid_testcomplete" } result ]
	set err_result [ catch { exec rm -f "$opid_prechecking" } result ]
	set err_result [ catch { exec rm -f "$opid_pmichecking" } result ]
	
	
#	exec touch $Info(WorkLoadDir)/$logMsg
# change above command to below for catching exception. By Jiang Nan	
	if { [ catch { eval exec touch $Info(WorkLoadDir)/$logMsg } err ] } {
		WriteFile $LogFile "EndOfLot: Error in execute touch $Info(WorkLoadDir)/$logMsg for $err"
	} else {
	
	}
	
}

proc patrolCheck { } {

	global BinDir

	set proceed_prog "patrolDone"
	set station 

	#  start user password interface
	if { [winfo exists .login_menu] !=  } {
		# tk_dialog .patrolerr "Patrol Error" "" @$BinDir/pmi_patrol_error.xbm  "Check PMI password window exist. Please check PMI first."
		Login_Screen_Patrol .login_menu_patrol $proceed_prog  $station
	} else {
		Login_Screen_Patrol .login_menu_patrol $proceed_prog  $station
	}

}

proc patrolDone { } {

	global Patrol_setup LogFile LogDir BinDir Confirmed Info env name namePatrol


	if { ! [ file exists $Patrol_setup ] } {
		set msg "The Patrol Setup file not exists: $Patrol_setup \nPlease contact with data team!\nQuite Patrol."
		tk_dialog .patrolERR " Error " $msg warning  "OK"
		return
	}


	set handler [ open $Patrol_setup ]

	set this_host [ eval exec hostname ]

	if { [ file exist "/tmp/pmi_debug_patrol" ] } {
		set debug_patrol_handler [ open "/tmp/pmi_debug_patrol" ]
		set this_host [ gets $debug_patrol_handler ]
		close $debug_patrol_handler
	}

	PutsDebug "patrolDone: Patrol checking on  $this_host"

	set in_route 

	foreach line [split [read $handler] \n] {
	   # Process line
		if { [ string match "*$this_host*" $line ] } {

			set in_route 1

			# this host in in this group
			PutsDebug "patrolDone: using group - $line"
			set arr_level1 [ split $line ":" ]

			# get the hostname from the queue in front of this_host
			set host "Pre_defined_this_host"
			set host_pre "Pre_defined_this_host_PRE"
			set host_pre_temp "Pre_defined_this_host_PRE"

			set first_node "Not_defined"
			set last_node "Not_defined"

			foreach host [ string trim [ split [ lindex $arr_level1 1 ] ] " " ] {

				if { [ string length [ string trim $host ] ] >   && [ string equal $first_node "Not_defined" ]  \
				&& ! [ string equal $host "Pre_defined_this_host" ] } {
					set first_node $host
				}
				if { [ string length [ string trim $host ] ] >  && ! [ string equal $host "Pre_defined_this_host" ] } {
					set last_node $host
				}

				if { [ string equal $host $this_host ] } {
					PutsDebug "patrolDone: this host is $this_host "
					set host_pre $host_pre_temp
				} elseif { [ string length [ string trim $host ] ] >   } {
					set host_pre_temp $host
				} else {
					PutsDebug "patrolDone: blanks in route string"
				}
			}

			if { [ string equal $host_pre "Pre_defined_this_host_PRE" ] } {  set host_pre $last_node }
                 # get the current status of the route
			if { ! [ file writable "${Patrol_setup}_[ lindex $arr_level1  ]" ] } {
				set msg "Patrol history file not writable: ${Patrol_setup}_[ lindex $arr_level1  ]"
				set msg "$msg\nPlease contact with Data Team!\nQuite Patrol!"
				tk_dialog .patrolERR " Error " $msg warning  "OK"
				return
			}

			set prev_host "NOT_START"
			if { [ file exist "${Patrol_setup}_[ lindex $arr_level1  ]" ] } {
				set status_handler [ open "${Patrol_setup}_[ lindex $arr_level1  ]" ]
				set prev_host [ gets $status_handler ]
				close $status_handler
			} 

			if { ! [ string match "*$prev_host*" $line ] } {
				set prev_host "NOT_START"
			}

                 # compare and record the patrol history
			if { [ string equal $prev_host $host_pre ] || \
			  ( [ string equal $prev_host "NOT_START" ] && [ string equal $this_host $first_node ])  } {

				PutsDebug "patrolDone: Patrol done [clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"] [ lindex $arr_level1  ] $this_host"
				set msg "Patrol Check has been done on host: $this_host"
				tk_dialog .patrolERR " Patrol Done " $msg warning  "OK"

				# write log and update the status file
				# do not update since 21248  --- JiangNan.
				set log_handler [ open "$LogDir/pmi/patrol.log" "a" ]
				puts $log_handler "[clock format [ clock seconds ] -format "%Y%m%d %H:%M:%S"] [ lindex $arr_level1  ] $namePatrol PATROL on $this_host"
				close $log_handler

				# update the status file
				set status_handler [ open "${Patrol_setup}_[ lindex $arr_level1  ]" "w" ]
				puts $status_handler $this_host
				close $status_handler
                   
				# Out Work Load Information
				set CURR_TIME [ clock format [ clock seconds ] -format "%Y%m%d%H%M%S"]
				if { [ string equal $Info(Device) "N/A" ] } {  
					set Device "NotSetUp"
				} else {
					set Device $Info(Device)
				}
				if [ catch { set waferID [ format "%2d" [lindex [ split $Info(WaferID) "-" ] 1] ] } ]  {
					set waferID "NoWaferIDAssigned"
				} 
				set logMsg [join [list $env(PROMIS_NAME) $CURR_TIME [string toupper $Confirmed] $Device $Info(LotID) $waferID $Info(PassNumber) "CHK"] "_"]
				WriteFile $Info(WorkLoadLog) "$logMsg"
				PutsDebug "patrolDone: workload - $logMsg"

#				exec touch $Info(WorkLoadDir)/$logMsg
# change above command to below for catching exception. By Jiang Nan			
				if { [ catch [eval exec touch $Info(WorkLoadDir)/$logMsg ] err ] } {
					WriteFile $LogFile "Error in execute touch $Info(WorkLoadDir)/$logMsg for $err"
				} else {

				}

			} else {

				set host_next "Not_defined"

				foreach host [ string trim [ split [ lindex $arr_level1 1 ] ] " " ] {
					if { [ string equal $host $prev_host ] } {
						set host_next "NextHost_is_NextinArray"
					} elseif { [ string length [ string trim $host ] ] >  && \
							 [ string equal $host_next "NextHost_is_NextinArray" ] } {
						set host_next $host
					}
				}

				if { [ string equal $host_next "NextHost_is_NextinArray" ] } {
		            set host_next $first_node
				}


				PutsDebug "LoadConfig: ROUTE=[ lindex $arr_level1  ] Patrol done on =$prev_host, next should be: $host_next"
				tk_dialog .patrolerr "Patrol Error" "" @$BinDir/pmi_patrol_error.xbm  "Patrol is not allowed on this tester. Please start from:     $host_next !"
		     # tk_dialog .patrolerr "Patrol Error" "" @$BinDir/abort.xbm  "Patrol is not allowed on this tester. Please start from $host_next !"
			}


		}
               # finish the if this host in route
	}
           # finish the foreach of Patrol_setup lines

	close $handler

	if { $in_route == 1 } {
		PutsDebug "patrolDone: Patrol Done."

	} else {
		PutsDebug "patrolDone: This host ( $this_host ) is not in routes."

		set msg "This host ( $this_host ) is not in routes. Available routes:\n"

		set handler [ open $Patrol_setup ]
		foreach line [split [read $handler] \n] {
			set arr_level1 [ split $line ":" ]
			set route_name [string trim [lindex $arr_level1 ] ]

			set next_host ""
			set group_name ""

			if { [ string length [ string trim $line ] ] >  } { 
				set prev_host "NOT_START"
				if { [ file exist "${Patrol_setup}_${route_name}" ] } {
					set status_handler [ open "${Patrol_setup}_${route_name}" ]
					set prev_host [ gets $status_handler ]
					if { [ string length [string trim $prev_host] ] ==  }  { set prev_host "NOT_START" }
					close $status_handler
				}
				if { ! [ string match "*$prev_host*" $line ] } { set prev_host "NOT_START" }

				set first_host [string trim [lindex [split [string trim [ lindex $arr_level1 1 ]] " "] ] ]

				set found_prev_host 
				foreach host [ string trim [ split [ lindex $arr_level1 1 ] ] " " ] {
					if { $found_prev_host == 1 } {
						set found_prev_host 
						set next_host $host
					}
					if { [ string equal $host $prev_host ] } {
						set found_prev_host 1
					}
				}

				if { [string equal $prev_host $host] } {  set next_host $first_host }
				if { [string equal $prev_host "NOT_START" ] } {  set next_host $first_host }
				set msg "$msg\n$route_name: next patrol node = $next_host"
			}
		}
		close $handler
		tk_dialog .patrolERR " Patrol Done " $msg warning  "OK"
	}
}

proc Login_Screen {screen proceed_prog station} {

	global Confirmed name password
	global S P ST

	if [winfo exists $screen] return

	set S $screen
	set P $proceed_prog
	set ST $station
	wm withdraw .
	wm geometry . {}

	toplevel $screen
	wm geometry $screen "-3-4"
	wm deiconify $screen
	wm resizable $screen false false
	wm protocol $screen WM_DELETE_WINDOW { destroy $S }
	wm title $screen "TJN-FM User Authentication Screen"
	wm protocol $screen WM_DELETE_WINDOW "Login_Screen $screen $proceed_prog $station"

	tkwait visibility $screen
	focus -force $screen
	#grab set -global $screen

	frame $screen.row
	label $screen.row.l -text " Plese Enter Your OneIT Password "
	pack  $screen.row.l -side right -padx 1 -pady 8

	frame $screen.rows
	label $screen.rows.l -text "Login:" -anchor e
	entry $screen.rows.e -textvariable name -width 15
	grid  $screen.rows.l $screen.rows.e -padx 6 -pady 4

	label $screen.rows.l1 -text "Password:" -anchor e
	entry $screen.rows.e1 -textvariable password -width 15 -show *
	grid  $screen.rows.l1 $screen.rows.e1 -padx 6 -pady 4


	frame  $screen.row3
	#button $screen.row3.b1 -text "Cancel" -command { destroy $screen }
	button $screen.row3.b2 -text "Confirm" -command { Show_Result $S $P $ST}
	pack $screen.row3.b2 -side left -expand yes -fill both -padx 1 -pady 8

	focus $screen.rows.e

	bind $screen.rows.e <Return> \
	{
		focus $S.rows.e1
	}

	bind $screen.rows.e1 <Return> \
	{
		$S.row3.b2 configure -state active
		focus $S.row3.b2
	}

	bind $screen.row3.b2 <Return> { Show_Result $S $P $ST}
	pack $screen.row $screen.rows $screen.row3 -side top
}

proc Login_Screen_Patrol {screen proceed_prog station} {

	global Confirmed name password
	global S_P P_P ST_P

	if [winfo exists $screen] return

	set S_P $screen
	set P_P $proceed_prog
	set ST_P $station
	wm withdraw .
	wm geometry . {}

	toplevel $screen
	wm geometry $screen "-3-4"
	wm deiconify $screen
	wm resizable $screen false false
	wm protocol $screen WM_DELETE_WINDOW { destroy $S_P }
	wm title $screen "TJN-FM Patrol User Authentication Screen"

	tkwait visibility $screen
	focus -force $screen
	#grab set -global $screen

	frame $screen.row
	label $screen.row.l -text " Plese Enter Your OneIT Password "
	pack  $screen.row.l -side right -padx 1 -pady 8

	frame $screen.rows
	label $screen.rows.l -text "Login:" -anchor e
	entry $screen.rows.e -textvariable name -width 15
	grid  $screen.rows.l $screen.rows.e -padx 6 -pady 4

	label $screen.rows.l1 -text "Password:" -anchor e
	entry $screen.rows.e1 -textvariable password -width 15 -show *
	grid  $screen.rows.l1 $screen.rows.e1 -padx 6 -pady 4


	frame  $screen.row3
	#button $screen.row3.b1 -text "Cancel" -command { destroy $screen }
	button $screen.row3.b2 -text "Confirm" -command { Show_Result $S_P $P_P $ST_P}
	pack $screen.row3.b2 -side left -expand yes -fill both -padx 1 -pady 8

	focus $screen.rows.e

	bind $screen.rows.e <Return> \
	{
		focus $S.rows.e1
	}

	bind $screen.rows.e1 <Return> \
	{
		$S.row3.b2 configure -state active
		focus $S.row3.b2
	}

	bind $screen.row3.b2 <Return> { Show_Result $S_P $P_P $ST_P}
	pack $screen.row $screen.rows $screen.row3 -side top
}

proc Show_Result {screen proceed_prog station} {
	global name password Confirmed verify_passwd_prog namePatrol promisname
	global Info LogFile StationOwnerFile env RecordFile LogDir
	global opid_alert opid_pause opid_prechecking opid_pmichecking pre_checking
	global flag4PMI_No_Button P
	global site_trigger

	set namePatrol $name

	if { [winfo exists $screen] !=  } {
		destroy $screen
	}

	PutsDebug "Show_Result: $screen $proceed_prog $station "

        # YW
        # Check point to eliminate use of probe coordinator group account
	if { [string last $name "r42141"] ==  || [string last $name "R42141"] ==  } {
		set msg " Invalid login name! \n\n"
		set resp [ tk_dialog .shresult " Error " $msg warning  "Try Again" ]
		set Confirmed failed

		if { $resp ==  } {
			set name ""
			set password ""
			if { [ string equal $proceed_prog "Proceed_Probe" ] } {
				Login_Screen $screen $proceed_prog $station
			} elseif { [ string equal $proceed_prog "patrolDone" ] } {
				Login_Screen_Patrol $screen $proceed_prog $station
			} else {
				Login_Screen $screen $proceed_prog $station
			}
		}
	} else {
		set auth_cmd "$verify_passwd_prog $name $password"
		if { [catch { set result [ eval exec $auth_cmd ] } err] } {
			WriteFile $LogFile "ErrorMsg: auth_cmd error: $err"
			PutsDebug "Show_Result: auth_cmd error: $err"

			set msg " Invalid login or password! \n\n Try Again? "
			set resp [ tk_dialog .shresult " Error " $msg warning  "Yes" "No" ]
			set Confirmed failed
			if { $resp ==  } {
				set name ""
				set password ""
				if { [ string equal $proceed_prog "Proceed_Probe" ] } {
					Login_Screen $screen $proceed_prog $station
				} elseif { [ string equal $proceed_prog "patrolDone" ] } {
					Login_Screen_Patrol $screen $proceed_prog $station
				} else {
					Login_Screen $screen $proceed_prog $station
				}
			}
		} else {
			#set result [eval exec $auth_cmd]
			if { [string compare $result "successful"] ==   || \
				 [string compare $result ":Success"] ==    || \
				 [string compare $result "2:Valid Login"] ==         } {
				set Confirmed $name

                             # check if set StationOwnerFile
                               checkStationOwner $name

                             # handle different event for different authenticate
				if { [ string equal $proceed_prog "Proceed_Probe" ] } {
					set Info(PMI_START) [ clock seconds ]
					set CURRENT_TIME [ clock format $Info(PMI_START) -format "%Y/%m/%d %H:%M:%S"]

					set delay_min [expr ( $Info(PMI_START) - $Info(PMI_Time) ) / 6 ]
					set delay_sec [expr $Info(PMI_START) - $Info(PMI_Time) - $delay_min * 6]
					set delay "wait $delay_min min $delay_sec sec"

					#set msg "Show_Result: $CURRENT_TIME user $name entered password. $delay. Checking probe mark now .... "
					set msg "Show_Result: Device:$Info(Device),Lot:$Info(LotID),Pass:$Info(PassNumber),Wafer:$Info(WaferID), user $name entered password. $delay. Checking probe mark now .... "

					# modified by tantan 21-4-21 for pmi checking status show in floorview #
					if { $pre_checking ==  } {
						set err_result [ catch { exec rm -f "$opid_alert" } result ]
						set err_result [ catch { exec rm -f "$opid_pause" } result ]
						set err_result [ catch { exec rm -f "$opid_prechecking" } result ]
						set err_result [ catch { exec touch "$opid_pmichecking" } result ]
					}

					PutsDebug $msg
					WriteFile $LogFile $msg
					
					set Info(PMI_DELAY)  [expr $Info(PMI_START) - $Info(PMI_Time)]
					#set msg "PMI Wait:$Info(HOST),$Info(Device),$Info(LotID),$Info(PassNumber),$Info(WaferID),$Info(PCID),$Info(Total_Site),$Info(diex),$Info(diey),$name,$delay_tmp"
					#WriteFile $RecordFile $msg
					
					set comments " Operator respond PMI "
					
					set wafer_number [lindex [split $Info(WaferID) -] 1]
					set msg [Generate_EPR_Msg  "Productive" "$promisname \"\" \"\" true" "" "EQUIP_START" "\"SUBSTATE Running \" \"LOT_ID  $Info(LotID) \" \"DEVICE_ID $Info(Device)  \" \"REPROBE $Info(isReprobe)  \" \"COMMENTS $comments \" \"OPERATOR_ID $name  \" \"PROBECARD_ID $Info(PCID)  \" \"PROBECARD_TYPE $Info(PCType) \" \"WAFER_ID $wafer_number \" \"PASS  $Info(PassNumber)\" " " \"ALARM_TIME  \" "]
					puts "msg is $msg"
					if [catch { Msg_To_TTT $msg } err] {
						WriteFile $LogFile "Show_Result: change EMS to green error, error is $err"
					} else {
						WriteFile $LogFile "Show_Result: change EMS to green complete"
						#WriteFile "$LogDir/clock/clock.out.$Info(HOST)" "Show_Result: change EMS to green complete"
					}
					

					# Pop up a screen and wait for operator check probe mark. After check PMI, click OK to continue from here.
					set msg " Please check probe mark now. And continue probe when finish. "
					set resp [ tk_dialog .shresult_PMI " do PMI " $msg warning  "Continue Probe" ]

					# modified by tantan 21-4-21 for pmi status return to run in floorview #
					set pre_checking   
					set err_result [ catch { exec rm -f "$opid_alert" } result ]
					set err_result [ catch { exec rm -f "$opid_pause" } result ]
					set err_result [ catch { exec rm -f "$opid_prechecking" } result ]
					set err_result [ catch { exec rm -f "$opid_pmichecking" } result ]



					if { $resp ==  } {
						set name ""
						set password ""
						$proceed_prog $station
					}

				} elseif { [ string equal $proceed_prog "patrolDone" ] } {
					set CURRENT_TIME [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S"]
					set msg "Show_Result: $CURRENT_TIME user $name entered password. Patrol checking ..."
					PutsDebug $msg
					WriteFile $LogFile $msg

					set name ""
					set password ""
					$proceed_prog
#mark , this elseif function add by JN 
				} elseif { [ string equal $proceed_prog "Delay_PrePMI" ]  } {
					set CURRENT_TIME [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S"]
					set resp [Dialog_Prompt "Please enter the reason why you delay Pre-PMI"]
					set msg "Show_Result: $CURRENT_TIME user $name delay pre-pmi for reason: $resp"
					PutsDebug $msg
					WriteFile $LogFile $msg
				
				} else {
					set CURRENT_TIME [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S"]
					set msg "Show_Result: $CURRENT_TIME user $name entered password. For un-known event!"
					PutsDebug $msg
					WriteFile $LogFile $msg

					set name ""
					set password ""
					$proceed_prog $station
				}

			} else {
				WriteFile $LogFile "StatusMsg: wrong password detected: $name $password"
				set msg " Invalid login or password! \n\n Try Again? "
				set resp [ tk_dialog .shresult " Error " $msg warning  "Yes" "No" ]
				set Confirmed failed

				if { $resp ==  } {
					set name ""
					set password ""
					Login_Screen $screen $proceed_prog $station
				} elseif { $resp == 1 } {
					if { [string compare $P "Delay_PrePMI"] ==  } {
						PrePMI $station 
					} elseif { [string compare $P "Proceed_Probe"] == } {
						set flag4PMI_No_Button 1
						PutsDebug "Show_Result: proceed_probe pmi "
						doPMI $station $site_trigger
					} else {

					}
				} 
			}
		}
	}
}

proc checkStationOwner { name } {
    global env Info StationOwnerFile

    set name [getStationOwnerName $name]

    if { [ file readable $StationOwnerFile ] } {
		set FH [ open $StationOwnerFile r+ ]
		set StationOwnerSetAlready 
		foreach line [ split [ read $FH ] \n ] {
			if { [ string match "*$env(PROMIS_NAME)*" $line ] } {
				set StationOwnerSetAlready 1
				break
			} 
		}

		if {  $StationOwnerSetAlready ==   } {
			PutsDebug "checkStationOwner: StationOwner: $env(PROMIS_NAME) $name"
			puts $FH "$env(PROMIS_NAME),$name"
			.buttonMenu.owner configure -bg green -text " OWNER: $name "
		} else {
			PutsDebug "checkStationOwner: StationOwner: $line   --- current PMI user: $name"
			set realStationOwner [ lindex [ split $line "," ] 1 ]
			.buttonMenu.owner configure -bg green -text " OWNER: $realStationOwner "
		}
		close $FH
    } else {
		set FH [ open $StationOwnerFile w+ ]
		PutsDebug "checkStationOwner: StationOwner: $env(PROMIS_NAME) $name"
		puts $FH "$env(PROMIS_NAME),$name new"
		.buttonMenu.owner configure -bg green -text " OWNER: $name "
		close $FH
    }
}

proc setupStationOwner { station } {

    global Info env StationOwnerFile pmi_supers StationOwnerConfirmed Confirmed name password newStationOwner verify_passwd_prog
    global LogFile BinDir

    set currentH [ clock format [ clock seconds ] -format "%H"]
    set currentM [ clock format [ clock seconds ] -format "%M"]

    set currentT "$currentH$currentM"

    PutsDebug "setupStationOwner: Manually set StationOwner"

    if { [ string compare $currentT "83" ] == 1 && [ string compare $currentT "9" ] == -1 } {
		PutsDebug "change owner"
    } else {
		PutsDebug "not time window"
    }


    # check if the owner is set, if set need Supper to Change

    set StationOwnerChanged 

    if { [ file readable $StationOwnerFile ] } {
		set FH [ open $StationOwnerFile r+ ]
		set StationOwnerSetAlready 
		foreach line [ split [ read $FH ] \n ] {
			if { [ string match "*$env(PROMIS_NAME)*" $line ] } {
				set StationOwnerSetAlready 1
				break
			}
		}

		if {  $StationOwnerSetAlready == 1  } {
			set Confirmed ""
			PutsDebug "setupStationOwner: StationOwner not set. Asking user for OneIT password"
			Login_Screen_StationOwner .login_owner "USER" $station

			tkwait variable StationOwnerConfirmed

            if { [string last $name "r42141"] ==  || [string last $name "R42141"] ==  } {
                set msg " Invalid login name! Please try again!\n\n"
                set resp [ tk_dialog .shresult " Error " $msg warning  "Close" ]
                set Confirmed failed

                WriteFile $LogFile "ErrorMsg:  try to use invalid account $name $password"
                PutsDebug "PMI WARN:  try to use account $name $password"

                if { $resp ==  } {
					set name ""
					set password ""
					# do nothing and need user click on the button again
                }
            } else {
                set auth_cmd "$verify_passwd_prog $name $password"
                if { [catch { set result [eval exec $auth_cmd] } err] } {
					WriteFile $LogFile "ErrorMsg: auth_cmd error: $err"
					PutsDebug "LoadConfig: auth_cmd error: $err" 

					set msg " Authenticate System Error! \n\n Please Try Again? "
					set resp [ tk_dialog .shresult " Error " $msg warning  "Close" ]
					set Confirmed failed

					WriteFile $LogFile "ErrorMsg:  Authenticate System Error( $name $password )"
					PutsDebug "PMI WARN:  Authenticate System Error( $name $password )"

					if { $resp ==  } {
						set name ""
						set password ""
						# do nothing and need user click on the button again
					}
                } else {
                        # set result [eval exec $auth_cmd]
					if { [string compare $result "successful"] ==   || \
						[string compare $result ":Success"] ==    || \
						[string compare $result "2:Valid Login"] ==         } {
						set Confirmed $name

						# set StationOwnerFile
						set name [getStationOwnerName $name]
						PutsDebug "setupStationOwner: StationOwner: $env(PROMIS_NAME) $name"
						puts $FH "$env(PROMIS_NAME),$name"
						WriteFile $LogFile "InfoMesg: manually change station owner by $name"
						.buttonMenu.owner configure -bg green -text " OWNER: $name "

					} else {
						WriteFile $LogFile "StatusMsg: wrong password detected: $name $password"
						set msg " Invalid login or password! \n\n Please Try Again. "
						set resp [ tk_dialog .shresult " Error " $msg warning  "Close" ]
						set Confirmed failed

						if { $resp ==  } {
							set name ""
							set password ""
							# do nothing and need user click on the button again
						}
					}
                }
			}
		} else {

            set Confirmed ""
            PutsDebug "setupStationOwner: StationOwner set already. Asking super for OneIT password to change"

            Login_Screen_StationOwner .login_owner "SUPER" $station

            tkwait variable StationOwnerConfirmed

            set isSuper 
            if { [ file readable $pmi_supers ] } {
				set FH_SUPER [ open $pmi_supers r ]
				foreach super [ split [ read $FH_SUPER ] \n ] {
					if { [ string tolower $name ] == [ string tolower $super ] } {
					set isSuper 1
					}
				}
               close $FH_SUPER

            }

            if { [string last $name "r42141"] ==  || [string last $name "R42141"] ==  } {
                set msg " Invalid login name! Please try again!\n\n"
                set resp [ tk_dialog .shresult " Error " $msg warning  "Close" ]
                set Confirmed failed

                WriteFile $LogFile "ErrorMsg:  try to use invalid account $name $password"
                PutsDebug "PMI WARN:  try to use invalid account $name $password"

                if { $resp ==  } {
					set name ""
					set password ""
					# do nothing and need user click on the button again
                }
            } elseif { $isSuper ==  } {
                set msg " Login User is not a SUPER! Please try again!\n\n"
                set resp [ tk_dialog .shresult " Error " $msg warning  "Close" ]
                set Confirmed failed

                WriteFile $LogFile "ErrorMsg:  try to use invalid account $name $password"
                PutsDebug "PMI WARN:  try to use invalid account $name $password"
            } else {
                set auth_cmd "$verify_passwd_prog $name $password"
                if { [catch { set result [eval exec $auth_cmd] } err] } {
					WriteFile $LogFile "ErrorMsg: auth_cmd error: $err"
					PutsDebug "LoadConfig: auth_cmd error: $err" 

					set msg " Authenticate System Error! \n\n Please Try Again? "
					set resp [ tk_dialog .shresult " Error " $msg warning  "Close" ]
					set Confirmed failed

					WriteFile $LogFile "ErrorMsg:  Authenticate System Error( $name $password )"
					PutsDebug "PMI WARN:  Authenticate System Error( $name $password )"

					if { $resp ==  } {
						set name ""
						set password ""
						# do nothing and need user click on the button again
					}
                } else {
                        # set result [eval exec $auth_cmd]
					if { [string compare $result "successful"] ==   || \
						 [string compare $result ":Success"] ==    || \
						 [string compare $result "2:Valid Login"] ==         } {
						set Confirmed $name

						 # set StationOwnerFile
						set newStationOwner [getStationOwnerName $newStationOwner]
						PutsDebug "setupStationOwner: PrevStationOwner: $line   --- newStationOwner $newStationOwner - changed by $name"
						WriteFile $LogFile "newOwner: newStationOwner $newStationOwner - changed by: $name"

						# puts $FH "$env(PROMIS_NAME),$newStationOwner"
						set StationOwnerChanged 1
						.buttonMenu.owner configure -bg green -text " OWNER: $newStationOwner "

					} else {
						WriteFile $LogFile "setupStationOwner: wrong password detected: $name $password"
						set msg " Invalid login or password! \n\n Please Try Again. "
						set resp [ tk_dialog .shresult " Error " $msg warning  "Close" ]
						set Confirmed failed

						if { $resp ==  } {
							set name ""
							set password ""
							# do nothing and need user click on the button again
						}
					}
                }
			}

		}
		close $FH

		if { $StationOwnerChanged == 1 } {
			set StationOwnerList {}
			set FH [ open $StationOwnerFile r ]
			foreach line [ split [ read $FH ] \n ] {
				if { [ string match "*$env(PROMIS_NAME)*" $line ] } {
					lappend StationOwnerList "$env(PROMIS_NAME),$newStationOwner"
				} else {
					if { [ string trim $line ] != "" } {
						lappend StationOwnerList $line
					}
				}
			}
			close $FH

			set FH [ open $StationOwnerFile w ]
			foreach line $StationOwnerList {
				puts $FH $line
			}
			close $FH
		}
    } else {
		set FH [ open $StationOwnerFile w+ ]
		puts $FH ""
		close $FH
		setupStationOwner 
    }


}

proc updateStationOwner { station } {

    global Info env StationOwnerFile Confirmed

    if { [ file readable $StationOwnerFile ] } {
		set FH [ open $StationOwnerFile r+ ]
		set StationOwnerSetAlready 
		foreach line [ split [ read $FH ] \n ] {
			if { [ string match "*$env(PROMIS_NAME)*" $line ] } {
				set StationOwnerSetAlready 1
				break
			}
		}

		if {  $StationOwnerSetAlready ==   } {
			PutsDebug "updateStationOwner: StationOwner: NOT SETUP"
			.buttonMenu.owner configure -bg yellow -text " OWNER:       "
		} else {
			PutsDebug "updateStationOwner: StationOwner: $line"
			set realStationOwner [ lindex [ split $line "," ] 1 ]
			set Confirmed [ lindex [ split $realStationOwner "-"]  ]
			.buttonMenu.owner configure -bg green -text " OWNER: $realStationOwner "
		}
		close $FH
    } else {
		PutsDebug "updateStationOwner: StationOwner: NOT SETUP"
		.buttonMenu.owner configure -bg yellow -text " OWNER:       "
    }
}

proc Login_Screen_StationOwner {screen proceed_prog station} {

	global StationOwnerConfirmed name password newStationOwner
	global S P ST

	if [winfo exists $screen] destroy $screen

	set S $screen
	set P $proceed_prog
	set ST $station

	set name ""
	set password ""
	set newStationOwner ""

	wm withdraw .
	wm geometry . {}

	toplevel $screen
	wm geometry $screen "-3-4"
	wm deiconify $screen
	wm resizable $screen false false
	wm protocol $screen WM_DELETE_WINDOW { destroy $S }
	wm title $screen "TJN-FM User Authentication Screen"


	tkwait visibility $screen
	focus -force $screen

	if { [ string equal $proceed_prog "USER" ] } {
		label $screen.tl     -text "   Setup Station Owner   "
		set usernamelabel "Login"
		set userpasslabel "Password"
	} else {
		label $screen.tl     -text "   Setup Station Owner   \n      Supper Only     "
		set usernamelabel "Super Login"
		set userpasslabel "Super Password"
	}
	pack $screen.tl

	frame $screen.row
	label $screen.row.l -text " Plese Enter Your OneIT Password "
	pack  $screen.row.l -side right -padx 1 -pady 8

	frame $screen.rows
	label $screen.rows.l -text "$usernamelabel:" -anchor e
	entry $screen.rows.e -textvariable name -width 15
	grid  $screen.rows.l $screen.rows.e -padx 6 -pady 4

	label $screen.rows.l1 -text "$userpasslabel:" -anchor e
	entry $screen.rows.e1 -textvariable password -width 15 -show *
	grid  $screen.rows.l1 $screen.rows.e1 -padx 6 -pady 4


	label $screen.rows.l3 -text "Station Owner:" -anchor e
	entry $screen.rows.e3 -textvariable newStationOwner -width 15
	if { ! [ string equal $proceed_prog "USER" ] } {
		grid  $screen.rows.l3 $screen.rows.e3 -padx 6 -pady 4
	}


	frame  $screen.row3
	button $screen.row3.b2 -text "Confirm" -command { if { [ string trim $name ] == "" } {
			set answer [ tk_dialog .warn "Warning" "Please input username!" {}  "Close" ]
			return
		}
		if { [ string trim $password ] == "" } {
			set answer [ tk_dialog .warn "Warning" "Please input password!" {}  "Close" ]
			return
		}
		if { ! [ string equal $P "USER" ] } {
			if { [ string trim $newStationOwner ] == "" } {
			set answer [ tk_dialog .warn "Warning" "Please input Station Owner!" {}  "Close" ]
				return
			}
		}
			set StationOwnerConfirmed $name
			destroy $S 
	}
	pack $screen.row3.b2 -side left -expand yes -fill both -padx 1 -pady 8

	focus $screen.rows.e

	bind $screen.rows.e <Return> \
	{
		focus $S.rows.e1
	}

	bind $screen.rows.e1 <Return> \
	{
		$S.row3.b2 configure -state active
		focus $S.row3.b2
	}

	#bind $screen.row3.b2 <Return> { Show_Result $S $P $ST}
	pack $screen.row $screen.rows $screen.row3 -side top
}

proc getStationOwnerName { coreid } {

    global pmi_operators

    set returnvalue "[string toupper $coreid]"

    if { [ file readable $pmi_operators ] } {

		set FH [ open $pmi_operators r ]
		foreach fullname [ split [ read $FH ] \n ] {
			if { [ lindex [ split $fullname , ]  ] == [ string toupper $coreid ] } {
				set returnvalue "[string toupper $coreid]-[ lindex [ split $fullname , ] 1 ]"
				break
			}
		}
		close $FH
		return $returnvalue
    } else {
		PutsDebug "getStationOwnerName: Can not read pmi_operators: $pmi_operators"
		return $returnvalue
    }
}

# next 3 function add by JN to support prompt window when delay pre-pmi

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
		return 
	} else {
		eval {toplevel $top} $args
		wm title $top $title
		return 1
	}
}

proc Dialog_Wait {top varName {focus {}}} {
	upvar $varName var
	bind $top <Destroy> [ list set $varName cancel]
	if {[string length $focus] == } {
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

proc Dialog_Prompt { string } {
	global prompt
	set f .prompt_by_pmi
	if [Dialog_Create $f "Prompt" -borderwidth 1 ] {
		message $f.msg -text $string -aspect 1
		entry $f.entry -textvariable prompt(result)
		set b [frame $f.buttons]
		pack $f.msg $f.entry $f.buttons -side top -fill x
		pack $f.entry -padx 5
		button $b.ok -text OK -command { set prompt(ok) 1 }
		button $b.cancel -text Cancel -command { set prompt(ok)  }
		pack $b.ok -side left
		pack $b.cancel -side right
		bind $f.entry <Return> {set prompt(ok) 1 ; break}
		bind $f.entry <Control-c> {set prompt(ok)  ; break }
	}
	set prompt(ok) 
	Dialog_Wait $f prompt(ok) $f.entry
	if {$prompt(ok)} {
		destroy .prompt_by_pmi
		return $prompt(result)
	} else {
		destroy .prompt_by_pmi
		return {}
	}
}

###############################################################
#	Socket Interface proc
#	socket module proc, please be careful when update module.
#	Usage:
###############################################################

proc Echo_Server {port} {
	global echo
	set echo(main) [socket -server EchoAccept $port]
}
proc EchoAccept {sock addr port} {
	global echo
#	PutsDebug "Accept $sock from $addr $port"
	set echo(addr,$sock) [list $addr $port]
	fconfigure $sock -buffering line
	fileevent $sock readable [list Echo $sock]
}
proc Echo {sock} {
	global echo Info ExtraTopWafersArray ExtraWafersArray ExcludeWafersArray flag4PrePMI
	if { [eof $sock] || [catch {gets $sock line}]} {
		close $sock
#		PutsDebug "Close $echo(addr,$sock)"
		unset echo(addr,$sock)
	} else {
		set operation [lindex [split $line] ]
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
# Main Function
#
# Register ourselves with the control loop for the events
# we are interested in.
#
###############################################################

set TTT_EVRDir "/exec/apps/bin/evr/TTT"

set Info(HOST) [ eval exec "hostname" ]
set BinDir "/exec/apps/bin/evr/PMI_evr"
set LogDir "/data/probe_logs"
set LogFile "$LogDir/pmi/pmi.out.$Info(HOST)"
set RecordFile "$LogDir/pmi/Record/pmi.record.txt"
set fablot_lotinfo "/exec/apps/bin/fablots/promis_data/lotinfo1.txt"   
set Debug_Flag "/tmp/pmi_debug_on"
#set Debug_Flag_DieLevel "/tmp/pmi_debug_on_dielevel"
set SocketPort 9998

set floorcell $env(SCCELLNUMBER)
set opid_alert "/floor/cells/cell_$floorcell/opid_alert"
set opid_pause "/floor/cells/cell_$floorcell/opid_pause"
set opid_name "/floor/cells/cell_$floorcell/opid_name"
set opid_testcomplete "/floor/cells/cell_$floorcell/opid_testcomplete"
set opid_prechecking "/floor/cells/cell_$floorcell/opid_prechecking"
set opid_pmichecking "/floor/cells/cell_$floorcell/opid_pmichecking"
set pre_checking 

set Info(WorkLoadLog) "/data/probe_logs/workload/$env(PROMIS_NAME)_$Info(HOST)_workload.log"
set Info(WorkLoadDir) "/data/transfer/loader/WorkLoad/incoming"


# Parameters used by password confirm
set verify_passwd_prog "/exec/apps/bin/ldap/ldap_auth_fsl"
set Confirmed failed
set name ""
set password ""

set PMI_Info "$BinDir/pmi_setup.txt"

set Patrol_setup "$BinDir/pmi_patrolsetup.txt"
set StationOwnerFile "$LogDir/pmi/StationOwnerFile"
set pmi_supers "$BinDir/pmi_supers"
set pmi_operators "$BinDir/pmi_operators"

option add *activeBackground orange
option add *selectBackground orange
option add *activeForeground black 
option add *highlightColor orange 

# connect to control loop; register callback procedures
evr connect localhost
evr bind infomessage InfoMessage
evr bind cellstatus  CellStatus
evr bind testresults TestResults
evr bind movecursor MoveCursor
evr bind startoflot StartOfLot
evr bind startofwafer StartOfWafer
evr bind endoflot 
evr bind waferinfo WaferInfo
evr bind statusmessage StatusMsg
evr bind endofwafer EndOfWafer
evr bind setupinfo SetupInfo

evr bind probecarddefine ProbeCardDefine


set Info(Uname) [ eval exec "uname" ]
set Info(UnameR) [ eval exec "uname -r" ]
set HPUX "HP-UX"
set SUNOS "SunOS"

# load TTT resource.

if [catch {source $TTT_EVRDir/Generate_EPR_Msg.tcl} result] {
	PutsDebug  "Failed to generate the EPR++ Message: $result."
	WriteFile $LogFile "Failed to generate the EPR++ Message: $result."
	exit
} 

if [catch {source $TTT_EVRDir/Msg_To_TTT.tcl} result] {
	PutsDebug "Failed to send the EPR++ Message to TTT: $result."
	WriteFile$ "Failed to send the EPR++ Message: $result."
	exit
}

set promisname None
set Retry_Times 

ResetAll 
ResetAll 1
if [ info exists env(PROMIS_NAME) ] {
    set promisname $env(PROMIS_NAME)
} else {
	if { [catch {set promisname [exec hostname]} err] } {
		WriteFile $LogFile "Main program: ERROR when set promisname : $err"
	} 
}


if [catch { Echo_Server $SocketPort } err ] { 
	PutsDebug "Failed startup Socket Daemon, Error: $err"
	exit 99
} else {
	PutsDebug "Success in startup Daemon	"
}


#
# Create Startup Message
#

wm overrideredirect . true
set sizes [wm maxsize .]
set x [expr {[lindex $sizes ]/2 - 175}]
set y [expr {[lindex $sizes 1]/2 - 7}]
wm geometry . "35x14+${x}+${y}"
label .l -bg green -fg black -bd 1 -relief raised -text " TJNPRB Probe Mark Inspection Monitor \n By JiangNan (c) 21 - 27 Freescale Inc"
pack .l -expand yes -fill both

after 4 {
	destroy .l
	wm withdraw .	
	wm geometry . {}
	
	toplevel .buttonMenu
	wm overrideredirect .buttonMenu true
	
	label .buttonMenu.l1 -bg #9478FF -fg white -text "Probe Mark Inspection \n\n version 4. By JiangNan"
	pack .buttonMenu.l1 -expand yes -fill both
	button .buttonMenu.owner -bg yellow -fg black -text " OWNER:        " -command {setupStationOwner }
	button .buttonMenu.pmi -bg green -fg black -text " Lot Has Not Started Yet "
	button .buttonMenu.addpmi -bg red -fg black -text " Additional Check "
	label .buttonMenu.blank1 -fg black -text "        "
	button .buttonMenu.patrol -bg green -fg black -text " Probe Patrol " -command patrolCheck
	pack .buttonMenu.owner .buttonMenu.pmi .buttonMenu.addpmi .buttonMenu.blank1 .buttonMenu.patrol -side top -expand yes -fill both
	wm geometry .buttonMenu "--26"
	wm deiconify .buttonMenu 


	# update the StationOwner
	updateStationOwner 

	# debug
	if {  == 1 } {
		#exec touch /tmp/pmi_debug_on
		set Info(PassNumber) 2
		InfoMessage  "Starting lot DJ12345.1Y"
		InfoMessage  "Reading setup Z11ZZ"

		StartOfLot 
		WaferInfo  1-1 2 test -2286 -2286  2 -1
		StartOfWafer 
		TestResults  1 1  1 1 1
		TestResults  1 2  1 1 1
		TestResults  1 3  1 1 1
		TestResults  1 4  1 1 1
		TestResults  1 5  1 1 1
		TestResults  1 6  1 1 1
		TestResults  1 7  1 1 1
		TestResults  1 8  1 1 1
		TestResults  1 9  1 1 1
		TestResults  1 1  1 1 1
		TestResults  1 11  1 1 1
		TestResults  1 12  1 1 1
		TestResults  1 13  1 1 1
		TestResults  1 14  1 1 1
		TestResults  1 15  1 1 1
		TestResults  1 16  1 1 1
		TestResults  1 17  1 1 1
		TestResults  1 18  1 1 1
		TestResults  1 19  1 1 1
		TestResults  1 2  1 1 1
		TestResults  1 21  1 1 1
		TestResults  1 22  1 1 1
		TestResults  1 23  1 1 1
		TestResults  1 24  1 1 1
		TestResults  1 25  1 1 1
		TestResults  1 26  1 1 1
		TestResults  1 27  1 1 1
		TestResults  1 28  1 1 1
		TestResults  1 29  1 1 1
		TestResults  1 3  1 1 1

		EndOfWafer 

		WaferInfo  1-1 2 test -2286 -2286  2 -1
		StartOfWafer 
		PutsDebug "$Info(Tested) $Info(TestableDie) [ expr { $Info(TestableDie) - $Info(Stop_Die_Count)}]"
		EndOfWafer 


		WaferInfo  1-2 2 test -2286 -2286  2 -1
		StartOfWafer 
		EndOfWafer 
		WaferInfo  1-2 2 test -2286 -2286  2 -1
		StartOfWafer 
		EndOfWafer 

		WaferInfo  1-3 2 test -2286 -2286  2 -1
		StartOfWafer 
		EndOfWafer 
		WaferInfo  1-3 2 test -2286 -2286  2 -1
		StartOfWafer 
		EndOfWafer 

		WaferInfo  1-4 2 test -2286 -2286  2 -1
		StartOfWafer 
		EndOfWafer 
		WaferInfo  1-4 2 test -2286 -2286  2 -1
		StartOfWafer 
		EndOfWafer 

		WaferInfo  1-5 2 test -2286 -2286  2 -1
		StartOfWafer 
		EndOfWafer 
		WaferInfo  1-5 2 test -2286 -2286  2 -1
		StartOfWafer 
		EndOfWafer 
		EndOfLot 
	}
}


