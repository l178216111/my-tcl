#!/usr/local/bin/wctksh
#

# IDENT provides a (static) global to hold the CVS/RCS Id string
# VER splits off the version number for use by the program

set IDENT {$Id: yield_monitor.tcl,v 10.00 2014/5/14 08:32:23 b39753 Exp $}
set VER [lindex [split $IDENT " "] 2]

set YMBIN /exec/apps/bin/evr/ymbin
set HOSTNAME [eval exec hostname]
set YM_CONFIG "$YMBIN/TJNconfig"
set YM_GEOMETRY "-2-2"
set SocketPort 9999

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

	global Info YMLOG 
	PutsDebug "InfoMessage: $message"
	WriteFile $YMLOG "InfoMessage: $message"
	
	if [regexp {^Network Transfer in Progress} $message] {
		# initialize ignore good bin var.
		set Info(IgnoreGood) 0
	}
	
	if [regexp {^Reading setup ([^ ]+)} $message match setup] {
		set Info(Setup_${station}) $setup
		set Info(Device) $setup
		LoadLimits $station
		LoadNavigatorParameters $station $setup
	}
	if { [ regexp {^Starting wafer pass of type (.+)$} $message match session] } {
		if { [ regexp {^Starting wafer pass of type RETEST BINS } $message ]  } {
#			WriteFile $YMLOG "InfoMessage: $message"
			set Info(autoreprobe) 1
		} elseif { [ regexp {^Starting wafer pass of type SAMPLE PROBE } $message]} {
			set Info(sampleprobe) 1
			set Info(autoreprobe) 0
		} else {
			set Info(autoreprobe) 0
		}
		set Info(Session) $session
	}
}

###############################################################
# Get Setup File Path
###############################################################
proc SetupName {station path file} {
	global Info
	set Info(SetupFileLocation) $path
}

###############################################################
# This procedure is developed to load parameters in setup file
# you can feel free add any load job in this proc
###############################################################
proc LoadNavigatorParameters {station setup} {
	global Info YMBIN YMLOG
	
# Abandoned by JiangNan, for we can get which bin is good bin in testtableinfo evr.
# Get Good Bin# from navigator setup file. Currently only support hardbin(0-255), you can feel free add softbin if comes requirement.
#
#	for {set i 0} { $i < 7 } {incr i} {
#		if [catch {set line [eval exec "$YMBIN/getVal $Info(SetupFileLocation)/$setup PSBN$i"] } err ] {
#			set message "Error In Reading setup file $Info(SetupFileLocation)/$setup, ErrorCode: $err"
#			WriteFile $YMLOG "LoadNavigatorParameters: $message"
#			PutsDebug "LoadLimits: $message"
#			genabortlotfunc "SUN System Error" "Meet system error:$err, the Yield Monitor can not continue. Please reboot SUN Station!!" "" $station
#		} else {
#			set BinList [split $line ""]
# only support P as Pass bin.
#			for {set j 0} {$j < 31} {incr j} {
#				if {[lindex $BinList $j] == "P"} {
#					set bin [expr 32*$i + $j]
#					lappend Info(GoodBinList) $bin 
#				}
#			}
#		}
#	}
# Get Good Bin# End
# Abandoned end

# Get test bin table
	for {set i 2} { $i <= 8 } {incr i} {
		for {set j 0} { $j <= 7 } {incr j} {
			if [catch {set line [eval exec "$YMBIN/getVal $Info(SetupFileLocation)/$setup MTB$i$j"] } err ] {
				set message "Error In Reading setup file $Info(SetupFileLocation)/$setup, ErrorCode: $err"
				WriteFile $YMLOG "LoadNavigatorParameters: $message"
				PutsDebug "LoadLimits: $message"
				genabortlotfunc "SUN System Error" "Meet system error:$err, the Yield Monitor can not continue. Please reboot SUN Station!!" "" $station
			} else {
				set TestBinList [split $line ""]
	# only support R as Reprobe bin.
				for {set k 0} {$k < 32} {incr k} {
					if {[lindex $TestBinList $k] == "R"} {
						set bin [expr 32*$j + $k]
						lappend Info(TestBinList:$i) $bin 
						#set message "$setup Info(TestBinList:$i) :  $Info(TestBinList:$i)"
                				#WriteFile $YMLOG "LoadNavigatorParameters: $message"
					}
				}
			}
		}
	}
# Get test bin table End



	
}

###############################################################
# Remember wafer rotation for use in creating wafermaps
###############################################################
proc SetupInfo {station wsize xsize ysize xref yref flat rotation yldhi yldlo lotid} {
	global Info YMLOG
	set Info(LotID) $lotid
	set Info(Rotation_${station}) $rotation
#	PutsDebug "SetupInfo: $Info(LotID) $Info(Rotation_$station)"
	if {[regexp {^C} $Info(LotID) ] ||[regexp {^KK} $Info(LotID) ] || [regexp {^GG} $Info(LotID) ]} {
		set Info(IsCLot) 1
	} else {
		set Info(IsCLot) 0
	}
	PutsDebug "SetupInfo: $Info(LotID) $Info(Rotation_$station) CLot = $Info(IsCLot)"
	WriteFile $YMLOG "SetupInfo: $Info(LotID) $Info(Rotation_$station) CLot = $Info(IsCLot)"
}

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
# Load limits from limits file.  If no limits are present
# for this setup, post a warning dialog.
###############################################################
proc LoadLimits {station} {

	global env Info YMBIN YMLOG NO_OCAP_DEV SAMPLE_DEV
	global Limit_File Bin_Limit_File Dut_Limit_File

	PutsDebug "LoadLimits: LoadLimits"

	if {![string compare $Info(Setup_${station}) "No Setup"]} return

	if {[regexp {^T+} "$Info(LotID)"] || [regexp {^t+} "$Info(LotID)"]} {
		set Info(IgnoreOCAPs) 0
	}

	# YW
	# New Code to Add Devices with OCAP disabled
	set NOCapDev [open "$NO_OCAP_DEV" "r"]
	while { ! [eof $NOCapDev]} {
		set Dev [gets $NOCapDev]
		if { [string compare $Info(Device) $Dev ] == 0 } {
			set Info(IgnoreOCAPs) 1
			WriteFile $YMLOG "LoadLimits: Matching None OCAP Device: $Info(Device)"
		}
	}
	close $NOCapDev

	# YW
	# heck to see whether this part does sample probe

	set SampleDev [open "$SAMPLE_DEV" "r"]
	while { ! [eof $SampleDev]} {
		set Dev [gets $SampleDev]
		if { [string last $Info(Device) $Dev ] >= 0 } {
			set Info(Sample) 1
			WriteFile $YMLOG "LoadLimits: Matching Sample Device: $Info(Device)"
		}
	}
	close $SampleDev

# unset old limits config  delta_
	foreach key [array names Info "Limit_*"] {
		unset Info($key)
	}
	#set Info(Limit_Min) 100
	foreach key [array names Info "delta_*"] {
		unset Info($key)
	}
	foreach key [array names Info "BinLimit_*"] {
		unset Info($key)
	}
	set Info(BinLimit_Min) 100

# end	
	
	set handle [open "$Limit_File"]
	inf iconfig
	iconfig load $handle
	close $handle
	
	# Start of lot OCAP check
	if { $Info(FirstWafer) == 1 && $Info(IgnoreOCAPs) == 0} {
		PutsDebug "LoadLimits: This lot is OCAP type"
		set cmd "/usr/bin/rm -f /tmp/yield.llcl /tmp/yield.wlcl /tmp/sol.out /tmp/eol.out /tmp/OCAPeow.out /tmp/OCAP.data /tmp/wafmap /tmp/outeredge"
		catch { eval exec $cmd }
		set cmd "$YMBIN/getLimits.sh $Info(Setup_${station}) $Info(PassNumber)"
		catch { eval exec $cmd }
		set context "Starting probe of $Info(Device) $Info(LotID)"
		WriteFile $YMLOG "LoadLimits: This lot is OCAP type, $context"
		.buttonMenu.mf.sl configure -bg lightgrey -fg black -text "SL: [ readFile "/tmp/SL.now" ]%"
		.buttonMenu.mf.wcl configure -bg lightgrey -fg black -text "WLCL: [ readFile "/tmp/WLCL.now" ]%"
		.buttonMenu.mf.lcl configure -bg lightgrey -fg black -text "LLCL: [ readFile "/tmp/LLCL.now" ]%"
		set cmd "/usr/bin/rm -f /tmp/LLCL.now /tmp/SL.now /tmp/WLCL.now"
		catch { eval exec $cmd }
	}

#	if [ catch { set time [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S" ] } ] {
#		set time N/A
#	}

	if [catch { set isetup [iconfig blocks -unique "DEFAULT"] }] {
		set context "No Default bin limit setup info in limits.txt"
		WriteFile $YMLOG "LoadLimits: $context"
		PutsDebug "LoadLimits: $context"
	} else {
		set ibins [$isetup blocks -unique -noerror bins ]
		if {$ibins != ""} {
			set context "Loading default bin limits"
			WriteFile $YMLOG "LoadLimits: $context"
			PutsDebug "LoadLimits: $context"
			# actually I don't want them to set other default key here, so I just get goodbin for default param.
			set Info(Limit_${station}:goodbin) [$ibins data -unique "goodbin"]
		} else {
			set context "Failed to Load Default bin limits"
			WriteFile $YMLOG "LoadLimits: $context"
			PutsDebug "LoadLimits: $context"
			tk_dialog .remind "Reminder" "Suspect No default limits in limits.txt!" info 0 "OK"
		}
		set Info(Limit_PercentMin_Config) [$isetup data -unique -noerror PercentageMin]
		set Info(Limit_Min_Config) 100
	}
	
	
	if [ catch {set MOO [eval exec "$YMBIN/find_moo $Info(Device) $Info(LotID) $Limit_File"]} err] {
		set context "Error finding setup in limits.txt for $Info(Device) $Info(LotID)  ErrorCode: $err"
		WriteFile $YMLOG  "LoadLimits: $context"
		PutsDebug "LoadLimits: $context"
		genabortlotfunc "SUN System Error" "Meet system error:$err, the Yield Monitor can not continue. Please reboot SUN Station!!" "" $station
	} else {
		if { [ string compare $MOO "NONE" ] == 0 } {
			set context "No setup in bin limit file for $Info(Device) $Info(LotID) "
			#comment by JiangNan because we have already set default in above DEFAULT block
			#set Info(Limit_Min) 100
			WriteFile $YMLOG "LoadLimits: $context"
			PutsDebug "LoadLimits: $context"
		} else {
			WriteFile $YMLOG "LoadLimits: Choose Moo $MOO"
			if [catch { set isetup [iconfig blocks -unique $MOO] }] {
				set context "No bin limit setup info for $Info(Device) $Info(LotID) "
				#set Info(Limit_Min) 100
				WriteFile $YMLOG "LoadLimits: $context"
				PutsDebug "LoadLimits: $context"
			} else {
				set ibins [$isetup blocks -unique -noerror bins_P${Info(PassNumber)} ]
				if {$ibins != ""} {
					set context "Loading bin limits for $Info(Device) Pass#$Info(PassNumber) $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"
				} else {
					set ibins [$isetup blocks -unique -noerror bins ]
					set context "Loading bin limits for $Info(Device) AllPass $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"
				}
					
				if {$ibins != ""} {
					set TempMin  [$isetup data -unique -noerror Min]
					if { ! [string equal $TempMin "" ]} {
						set Info(Limit_Min_Config) $TempMin 
					}
					set TempPercentMin  [$isetup data -unique -noerror PercentageMin]
					if { ! [string equal $TempPercentMin "" ]} {
						set Info(Limit_PercentMin_Config) $TempPercentMin 
					}
					foreach bin [$ibins data -noerror] {
						set Info(Limit_${station}:${bin}) [$ibins data -unique $bin]
					}
					set context [array get Info "Limit_*"]
					WriteFile $YMLOG "LoadLimits: $context"
				} else {
					set context "No bin limits block found for Device: $Info(Device) Lot: $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"
				}
				
				set icbin [$isetup blocks -unique -noerror Conse_P${Info(PassNumber)} ]
				if { $icbin != "" } {
					set context "Loading Conse limits for $Info(Device) Pass#${Info(PassNumber)} $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"
				} else {
					set icbin [$isetup blocks -unique -noerror Conse ]
					set context "Loading Conse limits for $Info(Device) AllPass $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"
				}
					
				if { $icbin != "" } {
					foreach cbin [$icbin data -noerror] {
						set Info(Limit_Conse_${station}:${cbin}) [$icbin data -unique $cbin]
					}
					set context [array get Info "Limit_Conse_*"]
					WriteFile $YMLOG "LoadLimits: $context"
				} else {
					set context "No Conse limits block found for Device: $Info(Device) Lot: $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"
				}
				
				
				set iscbin [$isetup blocks -unique -noerror SoftBins_conse_P${Info(PassNumber)} ]
				if { $iscbin != "" } {
					set context "Loading SoftBin Conse limits for $Info(Device) Pass#${Info(PassNumber)} $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"
				} else {
					set iscbin [$isetup blocks -unique -noerror SoftBins_conse]
					set context "Loading SoftBin Conse limits for $Info(Device) AllPass $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"
				}
					
				if { $iscbin != "" } {
					foreach scbin [$iscbin data -noerror] {
						set Info(Limit_SoftBin_Conse_${station}:${scbin}) [$iscbin data -unique $scbin]
					}
				} else {
					set context "No SoftBin Conse limits block found for Device: $Info(Device) Lot: $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"						
				}		
				
				
				set isbin [$isetup blocks -unique -noerror SoftBins_P${Info(PassNumber)} ]
				if { $isbin != "" } {
					set context "Loading SoftBin Non-Conse limits for $Info(Device) Pass#${Info(PassNumber)} $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"
				} else {
					set isbin [$isetup blocks -unique -noerror SoftBins]
					set context "Loading SoftBin Non-Conse limits for $Info(Device) AllPass $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"
				}
					
				if { $isbin != "" } {
					foreach sbin [$isbin data -noerror] {
						set Info(Limit_SoftBin_${station}:${sbin}) [$isbin data -unique $sbin]
					}
				} else {
					set context "No SoftBin Non-Conse limits block found for Device: $Info(Device) Lot: $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"						
				}		
			}
		}
	}

	# YW
	# New Code to get bin delta limits
	
	set handle [open "$Bin_Limit_File"]
	inf iconfig
	iconfig load $handle
	close $handle

	if [catch { set isetup [iconfig blocks -unique "DEFAULT"] }] {
		set context "No Default delta limit setup info in bin_limits.txt"
		WriteFile $YMLOG "LoadLimits: $context"
		PutsDebug "LoadLimits: $context"
	} else {
		set ibins [$isetup blocks -unique -noerror bin_delta ]
		if {$ibins != ""} {
			set context "Loading default delta limits"
			WriteFile $YMLOG "LoadLimits: $context"
			PutsDebug "LoadLimits: $context"
			# just accept goodbin default setting.
			set Info(delta_${station}:goodbin) [$ibins data -unique "goodbin"]
		} else {
			set context "Failed to Load Default delta limits"
			WriteFile $YMLOG "LoadLimits: $context"
			PutsDebug "LoadLimits: $context"
			tk_dialog .remind "Reminder" "Suspect No default limits in bin_limits.txt!" info 0 "OK"
		}
		set Info(Min_${station}_Config) [$isetup data -unique "min"]
	}
	
	
	if [ catch {set MOO [eval exec "$YMBIN/find_moo $Info(Device) $Info(LotID) $Bin_Limit_File"]} err] {
		set context "Error finding setup in bin delta limit file for $Info(Device) $Info(LotID)  $err"
		WriteFile $YMLOG "LoadLimits: $context"
		PutsDebug "LoadLimits: $context"
		genabortlotfunc "SUN System Error" "Meet system error:$err, the Yield Monitor can not continue. Please reboot SUN Station!!" "" $station
	} else {
		if { [ string compare $MOO "NONE" ] == 0 } {
			set context "No setup in bin delta limit file for $Info(Device) $Info(LotID), Setting to default "
			#set Info(Min_${station}) 100
			WriteFile $YMLOG "LoadLimits: $context"
			PutsDebug "LoadLimits: $context"
		} else {

			if [catch { set isetup [iconfig blocks -unique $MOO] }] {
				set context "Error reading bin delta limits for $Info(Device) $Info(LotID) "
#				set Info(Min_${station}) 100
				WriteFile $YMLOG "LoadLimits: $context"
				PutsDebug "LoadLimits: $context"
			} else {
				set ibins [$isetup blocks -unique -noerror bin_delta_P${Info(PassNumber)} ]
				if {$ibins != ""} {
					set context "Loading bin delta limits for $Info(Device) Pass#${Info(PassNumber)} $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"
				} else {
					set ibins [$isetup blocks -unique -noerror bin_delta ]
					set context "Loading bin delta limits for $Info(Device) AllPass $Info(LotID) "
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"
				}
				
				# add multi bin for Yuli.				
				if {$ibins != ""} {
					foreach bin [$ibins data -noerror] {
						set Info(delta_${station}:${bin}) [$ibins data -unique $bin]
					}
					set context [array get Info "delta_*"]
					WriteFile $YMLOG "LoadLimits: $context"
				} else {
					set context "No bin delta limits block defined for $MOO. No bin yield monitoring will be performed."
					WriteFile $YMLOG "LoadLimits: $context"
					PutsDebug "LoadLimits: $context"
				}
		
				# set minimal dies tested before monitoring
				#if [catch { set Info(Min_${station}) [$isetup data -noerror min] } ] {
				#	set Info(Min_${station}) 100
				#}
				
				set TempDeltaMin [$isetup data -unique -noerror min]  
				
				if {! [string equal $TempDeltaMin ""]} {
					set Info(Min_${station}_Config) $TempDeltaMin
				}
				
				# comment it because already set default in config file DEFAULT block
				#if {$Info(Min_${station}) == ""} {
				#	set Info(Min_${station}_Config) 100
				#}
			}
		}
	}

	# New Code to get bin limits for each site

	set handle [open "$Dut_Limit_File"]
	inf iconfig
	iconfig load $handle
	close $handle

	if [ catch {set MOO [eval exec "$YMBIN/find_moo $Info(Device) $Info(LotID) $Dut_Limit_File"]} err] {
		set context "Error finding setup in dut_limits.txt for $Info(Device) $Info(LotID) "
		WriteFile $YMLOG "LoadLimits: $context"
		PutsDebug "LoadLimits: $context"
		genabortlotfunc "SUN System Error" "Meet system error:$err, the yield monitor can not continue. Please reboot SUN Station!!" "" $station
	} else {
		if { [ string compare $MOO "NONE" ] == 0 } {
			set context "No setup in dut limit file for $Info(Device) $Info(LotID) "
			set Info(BinLimit_Min) 100
			WriteFile $YMLOG "LoadLimits: $context"
			PutsDebug "LoadLimits: $context"
		} else {
			if [catch { set isetup [iconfig blocks -unique $MOO] }] {
				set context "No dut limits setup for $Info(Device) $Info(LotID) "
				WriteFile $YMLOG "LoadLimits: $context"
				PutsDebug "LoadLimits: $context"
				set Info(Dut_${station}) 0
				set Info(BinLimit_Min) 100
			} else {
				set context "Loading dut limits for $Info(Device) $Info(LotID) "
				WriteFile $YMLOG "LoadLimits: $context"
				PutsDebug "LoadLimits: $context"
				set Info(Dut_${station}) 0
				foreach location $Info(Cardlayout_${station}) {
					set siteno [lindex $location 2]
					set dut D${siteno}_P${Info(PassNumber)}
					set ibins [$isetup blocks -unique -noerror $dut ]
					if {$ibins != ""} {
						set context "Loading dut limits for site $siteno"
						WriteFile $YMLOG "LoadLimits: $context"
						PutsDebug "LoadLimits: $context"
						foreach bin [$ibins data -noerror] {
							set Info(BinLimit_${station}_${siteno}:${bin}) [$ibins data -unique $bin]
							if { [ string match "<*" $Info(BinLimit_${station}_${siteno}:${bin}) ] } {
								set Info(BinLimit_${siteno}_BinGroup_Min) [ split $bin "+" ]
								set Info(BinLimit_${siteno}_Min_Yield) [lindex [split $Info(BinLimit_${station}_${siteno}:${bin}) "<" ] 1 ]
								set Info(BinLimit_Min) [$isetup data -unique -noerror Min]
								if { [string compare $Info(BinLimit_Min) "" ] == 0 } {
									set Info(BinLimit_Min) 100
								}
							}
							if { [ string match ">*" $Info(BinLimit_${station}_${siteno}:${bin}) ] } {
								set Info(BinLimit_${siteno}_BinGroup_Max) [ split $bin "+" ]
								set Info(BinLimit_${siteno}_Max_Yield) [lindex [split $Info(BinLimit_${station}_${siteno}:${bin}) ">" ] 1 ]
								set Info(BinLimit_Min) [$isetup data -unique -noerror Min]
								if { [string compare $Info(BinLimit_Min) "" ] == 0 } {
									set Info(BinLimit_Min) 100
								}
							}
						}
						set Info(Dut_${station}) 1
					} else {
						set dut D${siteno}
						set ibins [$isetup blocks -unique -noerror $dut ]
						if {$ibins != ""} {
							set context "Loading dut limits for site $siteno"
							WriteFile $YMLOG "LoadLimits: $context"
							PutsDebug "LoadLimits: $context"
							foreach bin [$ibins data -noerror] {
								set Info(BinLimit_${station}_${siteno}:${bin}) [$ibins data -unique $bin]
								if { [ string match "<*" $Info(BinLimit_${station}_${siteno}:${bin}) ] } {
									set Info(BinLimit_${siteno}_BinGroup_Min) [ split $bin "+" ]
									set Info(BinLimit_${siteno}_Min_Yield) [lindex [split $Info(BinLimit_${station}_${siteno}:${bin}) "<" ] 1 ]
									set Info(BinLimit_Min) [$isetup data -unique -noerror Min]
									if { [string compare $Info(BinLimit_Min) "" ] == 0 } {
										set Info(BinLimit_Min) 100
									}
								}
								if { [ string match ">*" $Info(BinLimit_${station}_${siteno}:${bin}) ] } {
									set Info(BinLimit_${siteno}_BinGroup_Max) [ split $bin "+" ]
									set Info(BinLimit_${siteno}_Max_Yield) [lindex [split $Info(BinLimit_${station}_${siteno}:${bin}) ">" ] 1 ]
									set Info(BinLimit_Min) [$isetup data -unique -noerror Min]
									if { [string compare $Info(BinLimit_Min) "" ] == 0 } {
										set Info(BinLimit_Min) 100
									}
								}
							}
							set Info(Dut_${station}) 1
						} else {
							set context "No bin limits set up for site $siteno"
							WriteFile $YMLOG "LoadLimits: $context"
							PutsDebug "LoadLimits: $context"
						}
					}
				}
			}
		}
	}
}

##############################################################
# We need to read the exit value of several files
#
##############################################################
proc readFile { fileName } {
	set exitVal 0
	if { [ file readable $fileName ] } {
		set inFile [ open $fileName "r" ]
		set exitVal [ read -nonewline $inFile ]
		close $inFile
	}
	return $exitVal
}

###############################################################
# When the probe card layout is defined, clear site counters
# and store layout info
###############################################################
proc ProbeCardDefine {station card_id card_type dib_id dib_type args} {

	global Info  YMLOG

	catch {unset Info(Cardlayout_${station})}

	set Info(Total_Site) 0
	foreach location $args {
		lappend Info(Cardlayout_${station}) $location
		set siteno [lindex $location 2]
		incr Info(Total_Site)
		PutsDebug "ProbeCardDefine:Reset site $siteno"
	}
	set Info(ProbeCardID) $card_id
	PutsDebug "ProbeCardDefind: Card ID is $card_id, Total_site is $Info(Total_Site)"
	WriteFile $YMLOG "ProbeCardDefind: Card ID is $card_id, Total_site is $Info(Total_Site)"
}

###############################################################
# This procedure stores a list of which bins are passing.
# (We don't just assume only bin 1)
#
###############################################################
proc TestTableInfo {station passlist colorlist colorgroups} {
	global Info YMLOG
	set Info(PassBinList_${station}) $passlist
	WriteFile $YMLOG "TestTableInfo: PassList $passlist"
}


proc LoadIgnoreHistory {} {
	global Info YM_TriggerHistory YMLOG
	PutsDebug "LoadIgnoreHistory: enter."
	
# unset old info
	foreach key [array names Info "IgnoreTrigger:*"] {
		unset Info($key)
	}

	set handle [open "$YM_TriggerHistory" "r"]
	while { ! [eof $handle]} {
		set line [gets $handle]
		if {[info exists Load]} {
			unset Load
		}
		if { [regexp {^IgnoreTrigger:(.+)\. \<\= record at .+$} $line match content] } {
			set array [split $content ","]
			foreach pair $array {
				set pair [string trim $pair]
				PutsDebug "LoadIgnoreHistory: pair = $pair"	
				set key [string trim [lindex [split $pair :] 0]]
#				set value [string trim [lindex [split $pair :] 1]]
				set value [string trimleft $pair $key]
				set value [string trimleft $value ":"]
				PutsDebug "LoadIgnoreHistory: key = $key, value = $value"
				set Load($key) $value
			}
			if {[string equal $Load(Level) "all"]} {
				set Info(IgnoreTrigger:$Load(LOTID):$Load(Pass)) 1
				PutsDebug "LoadIgnoreHistory: level:all $Load(LOTID) $Load(Pass)."
			} elseif {[string equal $Load(Level) "lot"]} {
				if {$Load(LOTID) == $Info(LotID) && $Load(Pass) == $Info(PassNumber)} {
					lappend Info(LotIgnoreFailureMode) $Load(FailureMode)
					PutsDebug "LoadIgnoreHistory: level:lot [array get Info LotIgnoreFailureMode]"
				}
			} else {
				WriteFile $YMLOG "LoadIgnoreHistory: Invalid Level $Load(Level)"
			}
		} else {
			PutsDebug "LoadIgnoreHistory: $line did not match any condition"
		}
		
	}
}

###############################################################
#
#	StartOfLot
#
###############################################################
proc StartOfLot {station} {

	global Info YMBIN  YMLOG

	PutsDebug "StartOfLot"
	set Info(WaferCount) 0
	set Info(FirstWafer) 1
	set Info(LotIgnoreFailureMode) ""
	LoadIgnoreHistory
# Abandon these var by JiangNan because I don't see them in use anywhere.
#	set Info(bin_limit_trigger_counter) 0
#	set Info(bin_limit_minyield_trigger_counter) 0
#	set Info(bin_limit_maxyield_trigger_counter) 0
#	set Info(bin_limit_conse_trigger_counter) 0
#	set Info(bin_limit_noconse_trigger_counter) 0
#	set Info(delta_limit_trigger_counter) 0
# END

#	if { $Info(stopped) == 1 } {
#		LoadLimits $station
#		set Info(ignore) 0
#		set Info(stopped) 0
#	}

# an external scripts that link device-M to device, device-N to device. out of scope of Yield Monitor.
# because integrator just support 1 layout card to 1 setup file, can not by 'pass/sort' differentiate, so we can only create link for -M -N together to DEVICE
	set cmd "$YMBIN/dir_check $Info(Setup_${station})_$Info(Device)_$Info(LotID)"
	catch { eval exec $cmd }

	WriteFile $YMLOG "StartOfLot"
#	set Info(Delta_Flag) 0
#	set Info(pause_flag) 0

}


###############################################################
#
# Extract show alarm from TestRestuls, TestResults would 
#	trigger multiply
#
###############################################################
proc EndOfTest {station sot_sec eot_sec } {
	global Info YMBIN YMLOG	
	
	PutsDebug "EndOfTest: start, $Info(Tested) Tested, Info(Min_Session) = $Info(Min_Session), Info(Limit_Min) = $Info(Limit_Min)"
	
	if {$Info(InPause) == 1} {
		evr send pause $station
#		tk_dialog .remind "Reminder" "Suspect there is a login window background, pause integrator, please check!" info 0 "OK"
	}
	
	# consider effective, so separate logic.
	if {$Info(Tested) > $Info(Limit_Min)} {
		PutsDebug "EndOfTest: start, $Info(Tested) Tested > $Info(Limit_Min), now start monitor."
		foreach key [array names Info] {
		
			set pattern "^Limit_$station:(.+)\$"
			if [regexp $pattern $key match sortlist ]  {
				PutsDebug "EndOfTest: limit key = $key, sortlist = $sortlist."
				if { [regexp -nocase {goodbin} $sortlist ] } {
					# set default goodbin limit as configuration
					set yield [format %.2f [expr $Info(TotalGood) * 100.0 / $Info(Tested) ] ]
					if { [ regexp {\>\s*(\d+)\s*$} $Info(Limit_${station}:${sortlist}) match percentage ] } {
						if {$Info(Tested) > $Info(Limit_PercentMin)} { 
							if { $yield > $percentage } {
								if {[info exists Info(LimitMinTemp_${sortlist})] && $Info(Tested) < $Info(LimitMinTemp_${sortlist})} { 
									WriteFile $YMLOG "EndOfTest: Min for $sortlist is $Info(LimitMinTemp_${sortlist}), Tested:$Info(Tested). Hold Trigger high_yield. "
								} else {
									set context "match condition high_yield"
									PutsDebug "EndOfTest: $context $yield"
									TriggerYieldMonitor $station "high_yield" $sortlist $yield $percentage
								}
							}
						}
					} elseif {[ regexp {\<\s*(\d+)\s*$} $Info(Limit_${station}:${sortlist}) match percentage ]} {
						if {$Info(Tested) > $Info(Limit_PercentMin)} { 
							if { $yield < $percentage } {
								if {[info exists Info(LimitMinTemp_${sortlist})] && $Info(Tested) < $Info(LimitMinTemp_${sortlist})} { 
									WriteFile $YMLOG "EndOfTest: Min for $sortlist is $Info(LimitMinTemp_${sortlist}), Tested:$Info(Tested). Hold Trigger low_yield. "
								} else {
									set context "match condition low_yield"
									PutsDebug "EndOfTest: $context $yield"
									TriggerYieldMonitor $station "low_yield" $sortlist $yield $percentage
								}
							}
						}
					}
					
				} elseif { [regexp {\+} $sortlist] } {
					set counter 0
					foreach sort [split $sortlist "+"] {
						if {![info exists Info(Count_${station}:${sort})]} {
							set Info(Count_${station}:${sort}) 0
						}
						incr counter $Info(Count_${station}:${sort})
					}
					if { [ regexp {\>\s*(\d+)\s*$} $Info(Limit_${station}:${sortlist}) match percentage ] } {
						if {$Info(Tested) > $Info(Limit_PercentMin)} { 
							set failure [format %.2f [expr double($counter) / $Info(Tested) * 100.0 ] ]
							if {$failure > $percentage } {
								if {[info exists Info(LimitMinTemp_${sortlist})] && $Info(Tested) < $Info(LimitMinTemp_${sortlist})} {
									WriteFile $YMLOG "EndOfTest: Min for $sortlist is $Info(LimitMinTemp_${sortlist}), Tested:$Info(Tested). Hold Trigger high_yield. "
								} else {
									set context "match condition high_yield"
									PutsDebug "EndOfTest: $context"
									TriggerYieldMonitor $station "high_yield" $sortlist $failure $percentage
								}
							}
						}
						
					} elseif { [ regexp {\<\s*(\d+)\s*$} $Info(Limit_${station}:${sortlist}) match percentage ]} {
						if {$Info(Tested) > $Info(Limit_PercentMin)} { 
							set failure [format %.2f [expr double($counter) / $Info(Tested) * 100.0 ] ]
							if {$failure < $percentage } {
								if {[info exists Info(LimitMinTemp_${sortlist})] && $Info(Tested) < $Info(LimitMinTemp_${sortlist})} {
									WriteFile $YMLOG "EndOfTest: Min for $sortlist is $Info(LimitMinTemp_${sortlist}), Tested:$Info(Tested). Hold Trigger low_yield. "
								} else {
									set context "match condition low_yield"
									PutsDebug "EndOfTest: $context"
									TriggerYieldMonitor $station "low_yield" $sortlist $failure $percentage
								}
							}
						}
					} else {
						if { $counter >= $Info(Limit_${station}:${sortlist})} {
							if {[info exists Info(LimitTemp_${sortlist})] && $counter < $Info(LimitTemp_${sortlist})} {
								WriteFile $YMLOG "EndOfTest: TempLimit for $sortlist is $Info(LimitTemp_${sortlist}), counter:$counter. Hold Trigger bin. "
							} else {
								set context "match condition bin"
								PutsDebug "EndOfTest: $context"
								TriggerYieldMonitor $station "bin" $sortlist $counter $Info(Limit_${station}:${sortlist})
							}
						}
					}
					
				} else {
					set sort $sortlist
					if {![info exists Info(Count_${station}:${sort})]} {
						set Info(Count_${station}:${sort}) 0
					}
					if { [ string compare $Info(Limit_${station}:${sort}) "" ] != 0 && $Info(Limit_${station}:${sort}) != 0  } {
						if { [ regexp {\>\s*(\d+)\s*$} $Info(Limit_${station}:${sort}) match percentage ] } {
							if {$Info(Tested) > $Info(Limit_PercentMin)} { 
								set failure [format %.2f [expr double($Info(Count_${station}:${sort})) / $Info(Tested) * 100.0 ]]
								if {$failure > $percentage } {
									if {[info exists Info(LimitMinTemp_${sort})] && $Info(Tested) < $Info(LimitMinTemp_${sort})} {
										WriteFile $YMLOG "EndOfTest: Min for $sort is $Info(LimitMinTemp_${sort}), Tested:$Info(Tested). Hold Trigger high_yield. "
									} else {
										set context "match condition high_yield"
										PutsDebug "EndOfTest: $context"
										TriggerYieldMonitor $station "high_yield" $sort $failure $percentage 
									}
								}
							}
						} elseif { [ regexp {\<\s*(\d+)\s*$} $Info(Limit_${station}:${sort}) match percentage ]} {
							if {$Info(Tested) > $Info(Limit_PercentMin)} { 
								set failure [format %.2f [expr double($Info(Count_${station}:${sort})) / $Info(Tested) * 100.0 ] ]
								if {$failure < $percentage } {
									if {[info exists Info(LimitMinTemp_${sort})] && $Info(Tested) < $Info(LimitMinTemp_${sort})} {
										WriteFile $YMLOG "EndOfTest: Min for $sort is $Info(LimitMinTemp_${sort}), Tested:$Info(Tested). Hold Trigger low_yield. "
									} else {
										set context "match condition low_yield"
										PutsDebug "EndOfTest: $context"
										TriggerYieldMonitor $station "low_yield" $sort $failure $percentage 
									}
								}
							}
						} else {
#							PutsDebug "Count for bin#$sort $Info(Count_${station}:${sort}), Limit $Info(Limit_${station}:${sort})"
							if { $Info(Count_${station}:${sort}) >= $Info(Limit_${station}:${sort})} {
								if {[info exists Info(LimitTemp_${sort})] && $Info(Count_${station}:${sort}) < $Info(LimitTemp_${sort})} {
									WriteFile $YMLOG "EndOfTest: TempLimit for $sort is $Info(LimitTemp_${sort}), Count:$Info(Count_${station}:${sort}). Hold Trigger bin. "
								} else {
									set context "match condition bin"
									PutsDebug "EndOfTest: $context"
									TriggerYieldMonitor $station "bin" $sort $Info(Count_${station}:${sort}) $Info(Limit_${station}:${sort})
								}
							}
						}
					}
				}
			}
			
			set pattern "^Limit_SoftBin_$station:(.+)\$"
			if [regexp $pattern $key match binlist ]  {
				if { [regexp {\+} $binlist] } {
					set counter 0
					foreach bin [split $binlist "+"] {
						if {![info exists Info(SoftBin_Count_${station}:${sort})]} {
							set Info(SoftBin_Count_${station}:${sort}) 0
						}
						incr counter $Info(SoftBin_Count_${station}:${bin})
					}
					if { [ regexp {\>\s*(\d+)\s*$} $Info(Limit_SoftBin_${station}:${binlist}) match percentage ] } {
						set failure [format %.2f [expr double($counter) / $Info(Tested) * 100.0 ] ]
						if {$failure > $percentage } {
							TriggerYieldMonitor $station "high_yield" $binlist $failure $percentage
						}
					} elseif { [ regexp {\<\s*(\d+)\s*$} $Info(Limit_SoftBin_${station}:${binlist}) match percentage ]} {
						set failure [format %.2f [expr double($counter) / $Info(Tested) * 100.0 ] ]
						if {$failure < $percentage } {
							TriggerYieldMonitor $station "low_yield" $binlist $failure $percentage
						}
					} else {
						if { $counter >= $Info(Limit_SoftBin_${station}:${binlist})} {
							set context "match condition softbin"
							PutsDebug "EndOfTest: $context"
							TriggerYieldMonitor $station "softbin" $binlist $counter $Info(Limit_SoftBin_${station}:${binlist})
						}
					}
				} else {
					set bin $binlist
					if { [ string compare $Info(Limit_SoftBin_${station}:${bin}) "" ] != 0 && $Info(Limit_SoftBin_${station}:${bin}) != 0  } {
						if { [ regexp {\>\s*(\d+)\s*$} $Info(Limit_SoftBin_${station}:${bin}) match percentage ] } {
							set failure [format %.2f [expr double($Info(SoftBin_Count_${station}:${bin})) / $Info(Tested) * 100.0 ]]
							if {$failure > $percentage } {
								TriggerYieldMonitor $station "high_yield" $bin $failure $percentage 
							}
						} elseif { [ regexp {\<\s*(\d+)\s*$} $Info(Limit_SoftBin_${station}:${bin}) match percentage ]} {
							set failure [format %.2f [expr double($Info(SoftBin_Count_${station}:${bin})) / $Info(Tested) * 100.0 ]]
							if {$failure < $percentage } {
								TriggerYieldMonitor $station "low_yield" $bin $failure $percentage 
							}
						} else {
							if { $Info(SoftBin_Count_${station}:${bin}) >= $Info(Limit_SoftBin_${station}:${bin})} {
								set context "match condition softbin"
								PutsDebug "EndOfTest: $context"
								TriggerYieldMonitor $station "softbin" $bin
							}
						}
					}
				}
			}
			
			set pattern "^delta_$station:(.+)\$"
			if [regexp $pattern $key match sortlist ] {
				if {$Info(Tested) > $Info(Min_Session)} {
				# add goodbin by JiangNan
					PutsDebug "EndOfTest: start, $Info(Tested) Tested > $Info(Min_Session), now start delta monitor."
					if { [regexp -nocase {goodbin} $sortlist ] } {
						PutsDebug "EndOfTest: start,  now start delta monitor for goodbin."
						foreach location $Info(Cardlayout_${station}) {
							set siteno [lindex $location 2]
							if {![info exists Info(Good_${station}:${siteno})]} {
								set Info(Good_${station}:${siteno}) 0
							}
							if {![info exists Info(Total_${station}:${siteno}) ] || $Info(Total_${station}:${siteno}) == 0} {
								set  Info(BinYield_${station}_${siteno}:$sortlist)  0.0
							} else {
								set Info(BinYield_${station}_${siteno}:$sortlist) [format %.2f [expr {double($Info(Good_${station}:${siteno}))/$Info(Total_${station}:${siteno}) * 100.0 } ]]
							}
							set yield $Info(BinYield_${station}_${siteno}:$sortlist)
							if { $siteno == 0 } {
								set Info(Maxyield_${station}_${sortlist}) $yield
								set Info(Minyield_${station}_${sortlist}) $yield
								set Info(Max_Site) 0
								set Info(Min_Site) 0
							}
							if {$Info(Total_${station}:$siteno) > 0} {
								if { $yield >= $Info(Maxyield_${station}_${sortlist}) } {
									set Info(Maxyield_${station}_${sortlist}) $yield
									set Info(Max_Site) $siteno
								}
								if { $yield <= $Info(Minyield_${station}_${sortlist}) } {
									set Info(Minyield_${station}_${sortlist}) $yield
									set Info(Min_Site) $siteno
								}
							}
							
						}
						set Info(yield_diff) [expr {$Info(Maxyield_${station}_${sortlist}) - $Info(Minyield_${station}_${sortlist})}]
						PutsDebug "EndOfTest: start,   goodbin yield diff = $Info(yield_diff) ."
						if { $Info(yield_diff) > $Info(delta_${station}:${sortlist}) } {
							set context "match condition delta_diff"
							PutsDebug "EndOfTest: $context"
							# goodbin 
							set trans_site $Info(Min_Site)
							TriggerYieldMonitor $station "delta_diff" $sortlist $Info(yield_diff) $Info(delta_${station}:${sortlist}) $trans_site
						}
					} elseif { [regexp {\+} $sortlist ] } {
						foreach location $Info(Cardlayout_${station}) {
							set siteno [lindex $location 2]
							set counter 0
							foreach sort [split $sortlist "+"] {	
								if {![info exists Info(BinCount_${station}_${siteno}:$sort)]} {
									set Info(BinCount_${station}_${siteno}:$sort) 0
								}
							
								if { $Info(Total_${station}:$siteno) > 0 } {
									incr counter $Info(BinCount_${station}_${siteno}:$sort)
								} else {
									set Info(BinYield_${station}_${siteno}:$sortlist) 0.0
									continue
								}
								set Info(BinYield_${station}_${siteno}:$sortlist) [format %.2f [expr {double($counter)/$Info(Total_${station}:$siteno) * 100.0 }] ]
							}
							set yield $Info(BinYield_${station}_${siteno}:$sortlist)
							if { $siteno == 0 } {
								set Info(Maxyield_${station}_${sortlist}) $yield
								set Info(Minyield_${station}_${sortlist}) $yield
								set Info(Max_Site) 0
								set Info(Min_Site) 0
							}
							if {$Info(Total_${station}:$siteno) > 0} {
								if { $yield >= $Info(Maxyield_${station}_${sortlist}) } {
									set Info(Maxyield_${station}_${sortlist}) $yield
									set Info(Max_Site) $siteno
								}
								if { $yield <= $Info(Minyield_${station}_${sortlist}) } {
									set Info(Minyield_${station}_${sortlist}) $yield
									set Info(Min_Site) $siteno
								}
							}
						}
						set Info(yield_diff) [expr {$Info(Maxyield_${station}_${sortlist}) - $Info(Minyield_${station}_${sortlist})}]
						if { $Info(yield_diff) > $Info(delta_${station}:${sortlist}) } {
							set context "match condition delta_diff"
							PutsDebug "EndOfTest: $context"
							set sort [lindex [split $sortlist "+"] 0]
							if {[string index $Info(PassBinList_${station}) $sort]} {
								set trans_site $Info(Min_Site)
							} else {
								set trans_site $Info(Max_Site)
							}
							TriggerYieldMonitor $station "delta_diff" $sortlist $Info(yield_diff) $Info(delta_${station}:${sortlist}) $trans_site
						}
					} else {
						set sort $sortlist
						if { [info exists Info(delta_${station}:${sort})] && $Info(delta_${station}:${sort}) != 0 } {
							# redefine of max yield
							foreach location $Info(Cardlayout_${station}) {
								set siteno [lindex $location 2]
								if {![info exists Info(BinCount_${station}_${siteno}:$sort)]} {
									set Info(BinCount_${station}_${siteno}:$sort) 0
								}
								if { $Info(Total_${station}:$siteno) > 0 } {
									set Info(BinYield_${station}_${siteno}:$sort) [format %.2f [expr { double($Info(BinCount_${station}_${siteno}:$sort))/$Info(Total_${station}:$siteno)*100.0 }] ]
								} else {
									set Info(BinYield_${station}_${siteno}:$sort) 0.0
								}
								set yield $Info(BinYield_${station}_${siteno}:$sort)
								
								if { $siteno == 0 } {
									set Info(Maxyield_${station}_${sort}) $yield
									set Info(Minyield_${station}_${sort}) $yield
									set Info(Max_Site) 0
									set Info(Min_Site) 0
								}
								if {$Info(Total_${station}:$siteno) > 0} {
									if { $yield >= $Info(Maxyield_${station}_${sort}) } {
										set Info(Maxyield_${station}_${sort}) $yield
										set Info(Max_Site) $siteno
									}
									if { $yield <= $Info(Minyield_${station}_${sort}) } {
										set Info(Minyield_${station}_${sort}) $yield
										set Info(Min_Site) $siteno
									}
								}
							}
							set Info(yield_diff) [expr {$Info(Maxyield_${station}_${sort}) - $Info(Minyield_${station}_${sort})}]
							if { $Info(yield_diff) > $Info(delta_${station}:${sort}) } {
								set context "match condition delta_diff"
								PutsDebug "EndOfTest: $context"
								if {[string index $Info(PassBinList_${station}) $sort]} {
									set trans_site $Info(Min_Site)
								} else {
									set trans_site $Info(Max_Site)
								}
								TriggerYieldMonitor $station "delta_diff" $sort $Info(yield_diff) $Info(delta_${station}:${sort}) $trans_site
							}
						}
					
					}
				}
			}
		}
	}
}

###############################################################
# At the end of each test (this gets called for each site) DO:
#
#   increment bin count for the sort.  If count > limit, call
#      FailedBinLimit.
#
#   increment good die count for site if sort is a good die.
#      If any site exceeds highest yielding site by Delta,
#      call FailedDeltaLimit.
#
###############################################################
proc TestResults {station x y site test bin sort} {
	global Info YMBIN YMLOG 

	if { $site == -1 } {
		return
	}

	lappend Info(MapResult_${station}) "$x $y $sort"
	set Info(LastTestedDie) "$x,$y"
	
	
# upgrade goodbin as navigator defined / integrator returned, not const value 1,248-251	
	set binflag [string index $Info(PassBinList_${station}) $sort]
	
	if { $binflag == 1 } {	
		if {![info exists Info(TotalGood)]} {
			set Info(TotalGood) 1
		} else {
			incr Info(TotalGood)
		}
		if {![info exists Info(Good_${station}:${site})]} {
			set Info(Good_${station}:${site}) 1
		} else {
			incr Info(Good_${station}:${site})
		}
		set Info(GoodDie) 1
	} else {
		if {![info exists Info(TotalFail)]} {
			set Info(TotalFail) 1
		} else {
			incr Info(TotalFail)
		}
		
		set Info(GoodDie) 0
	}
# upgrade  good bin end
	
	if {![info exists Info(Tested)]} {
		set Info(Tested) 1
	} else {
		incr Info(Tested)
	}
	
	if {![info exists Info(BinCount_${station}_${site}:${sort}) ]} {
		set Info(BinCount_${station}_${site}:${sort})  1
	} else {
		incr Info(BinCount_${station}_${site}:${sort}) 
	}
	
	if {![info exists Info(Total_${station}:${site}) ]} {
		set  Info(Total_${station}:${site})  1
	} else {
		incr Info(Total_${station}:${site}) 
	}
	
	if {![info exists Info(Count_${station}:${sort})]} {
		set Info(Count_${station}:${sort}) 1
	} else {
		incr Info(Count_${station}:${sort})
	}
	
	

#	set Info(delta_group_${station}_{$i}_bins) [split $bin "+"]
#	set Info(delta_group_${station}_{$i}_value) [lindex [split [$ibins data -unique $bin] ":"] 1 ]
#	for {set i 0} {$i<$Info(delta_group_count)} {incr i} {
#		if {[lsearch -exact $Info(delta_group_${station}_${i}_bins) $sort] != -1 } {
#			incr Info(DeltaGroup_${station}_${i}_{$site}) 
#		}
#	}
	
# add if because some part like N23B test prog did not support 1000+ softbin, and return softbin is null / @@@ in INF file 20140617 by JiangNan

	if {[regexp {^\d+$} $bin ]} {
		if {![info exists Info(SoftBin_Count_${station}:${bin})]} {
			set Info(SoftBin_Count_${station}:${bin}) 1
		} else {
			incr Info(SoftBin_Count_${station}:${bin})
		}
		if {![info exists Info(Last_Failsoftbin:$site)] || [string compare "" $Info(Last_Failsoftbin:$site) ] != 0} {
			set Info(Last_Failsoftbin:$site) $bin
		} 
	} else {
		set context "softbin invalid: softbin=$bin hardbin=$sort!"
		PutsDebug "TestResults:"
		set Info(Last_Failsoftbin:$site) 0
	}

	if {![info exists Info(Last_Failbin:$site)] || [string compare "" $Info(Last_Failbin:$site) ] == 0 } {
		PutsDebug "setting Info(Last_Failbin:$site) to $sort"
		set Info(Last_Failbin:$site) $sort
	} 
	
	if {![info exists Info(Count_ConseBin:$site)]} {
		set Info(Count_ConseBin:$site) 0
	} 
	if {![info exists Info(Count_ConseSoftBin:$site)]} {
		set Info(Count_ConseSoftBin:$site) 0
	} 
	
#	set NoConse_bin ,${sort},		
#	if { [string first $NoConse_bin $Info(Limit_NonConsebins) ] != -1 } {
#		incr Info(Count_NoConse)
#	}
	
#	if {[info exists Info(Limit_Conse_${station}:${sort}) ] && $Info(Limit_Conse_${station}:${sort}) != 0} {
#	}
	
	if {[string compare $sort $Info(Last_Failbin:$site) ] == 0 } {
		incr Info(Count_ConseBin:$site)
		PutsDebug " sort =  $sort, Info(Last_Failbin:$site) = $Info(Last_Failbin:$site) ,incr Info(Count_ConseBin:$site) to $Info(Count_ConseBin:$site)"
	} else {
		set Info(Count_ConseBin:$site) 1
		set Info(Last_Failbin:$site) $sort
		PutsDebug "set Info(Count_ConseBin:$site) to 1,Info(Last_Failbin:$site) to $Info(Last_Failbin:$site)"
	}
	
	if {[info exists Info(Limit_SoftBin_Conse_${station}:${bin}) ] && $Info(Limit_SoftBin_Conse_${station}:${bin}) != 0} {
		if { [string compare $bin $Info(Last_Failsoftbin:$site) ] == 0 } {
			incr Info(Count_ConseSoftBin:$site)	
		} else {
			set Info(Count_ConseSoftBin:$site) 1
			set Info(Last_Failsoftbin:$site) $bin
		}
	}
	
	if {[info exists Info(Limit_Conse_${station}:${sort}) ] && $Info(Limit_Conse_${station}:${sort}) != 0} {
		if { $Info(Count_ConseBin:$site) >= $Info(Limit_Conse_${station}:${sort}) && [string compare $sort $Info(Last_Failbin:$site) ] == 0 } {
			set context "match condition Consebin, sort = $sort, Info(Limit_Conse_${station}:${sort}) = $Info(Limit_Conse_${station}:${sort}), Info(Last_Failbin:$site) = $Info(Last_Failbin:$site)"
			PutsDebug "TestResults: $context"
			TriggerYieldMonitor $station "Consebin" $sort $site $Info(Count_ConseBin:$site) $Info(Limit_Conse_${station}:${sort}) 
		}
	}
	# SoftBin Conse for Ruiyu. do not use in this version. 20140812.
	if {[info exists Info(Limit_SoftBin_Conse_${station}:${bin}) ] && $Info(Limit_SoftBin_Conse_${station}:${bin}) != 0} {
		if { $Info(Count_ConseSoftBin:$site) >= $Info(Limit_SoftBin_Conse_${station}:${bin}) } {
			set context "match condition Consesoftbin"
			PutsDebug "TestResults: $context"
			TriggerYieldMonitor $station "ConseSoftbin" $bin $site
		}
	}
	
	if  { $Info(Tested) > $Info(BinLimit_Min) } {	
		if { $Info(Dut_${station}) != 0 } {

			if { [info exists Info(BinLimit_${site}_BinGroup_Min) ] && $Info(BinLimit_${site}_BinGroup_Min) != 0 } {
				set Info(BinLimit_${site}_BinGroup_Min_Sum) 0
				foreach bin_no $Info(BinLimit_${site}_BinGroup_Min) {
					if {![info exists Info(BinCount_${station}_${site}:${bin_no})]} {
						set Info(BinCount_${station}_${site}:${bin_no}) 0
					}
					incr Info(BinLimit_${site}_BinGroup_Min_Sum) $Info(BinCount_${station}_${site}:${bin_no})
				}
				set Info(Min_Yield:$site) [format %.2f [ expr double($Info(BinLimit_${site}_BinGroup_Min_Sum))/$Info(Total_${station}:${site})*100.0 ] ]
				if {$Info(BinLimit_${site}_BinGroup_Min) != 0 && $Info(BinLimit_${site}_Min_Yield) != 0 && $Info(Min_Yield:$site) < $Info(BinLimit_${site}_Min_Yield)} {
					if {[info exists Info(DutMinLimitMinTemp:$site)] && $Info(Tested) < $Info(DutMinLimitMinTemp:$site)} {
						WriteFile $YMLOG "EndOfTest: Min for Site#$site is $Info(DutMinLimitMinTemp:${site}), Tested:$Info(Tested). Hold Trigger Dut min yield. "
					} else {
						set context "match condition Dut min yield Dut#$site $Info(Min_Yield:$site) < $Info(BinLimit_${site}_Min_Yield)"
						PutsDebug "TestResults: $context"
						TriggerYieldMonitor $station "Dut min yield" $Info(BinLimit_${site}_BinGroup_Min) $site $Info(Min_Yield:$site)
					}
				}
			} 

			if { [info exists Info(BinLimit_${site}_BinGroup_Max) ] && $Info(BinLimit_${site}_BinGroup_Max) != 0 } {
				set Info(BinLimit_${site}_BinGroup_Max_Sum) 0
				foreach bin_no $Info(BinLimit_${site}_BinGroup_Max) {
					if {![info exists Info(BinCount_${station}_${site}:${bin_no})]} {
						set Info(BinCount_${station}_${site}:${bin_no}) 0
					}
					incr Info(BinLimit_${site}_BinGroup_Max_Sum) $Info(BinCount_${station}_${site}:${bin_no})
				}
				set Info(Max_Yield:$site) [format %.2f [ expr double($Info(BinLimit_${site}_BinGroup_Max_Sum))/$Info(Total_${station}:${site})*100.0 ] ]
				if {$Info(BinLimit_${site}_BinGroup_Max) != 0 && $Info(BinLimit_${site}_Max_Yield) != 0 && $Info(Max_Yield:$site) > $Info(BinLimit_${site}_Max_Yield)} {
					if {[info exists Info(DutMaxLimitMinTemp:$site)] && $Info(Tested) < $Info(DutMaxLimitMinTemp:$site)} {
						WriteFile $YMLOG "EndOfTest: Min for Site#$site is $Info(DutMaxLimitMinTemp:${site}), Tested:$Info(Tested). Hold Trigger Dut max yield. "
					} else {
						set context "match condition Dut max yield Dut#$site $Info(Max_Yield:$site) < $Info(BinLimit_${site}_Max_Yield)"
						PutsDebug "TestResults: $context"
						TriggerYieldMonitor $station "Dut max yield" $Info(BinLimit_${site}_BinGroup_Max) $site $Info(Max_Yield:$site) 
					}
				}
			} 
			
			
			###################Consecutive Fail dut bin##############

#			if { $Info(GoodDie) == 0 } {
# comment by Jiang. 
# reason: 1. not any part use this.  2. dut conse bin monitor have already been covered by Conse bins, I just add by dut trigger in testresults function.
			
#				if { [ string compare $sort $Info(Last_Failbin_D${site}) ] == 0 } {
#					incr Info(Count_ConseBin_${site})
#					if { $Info(Count_ConseBin_${site}) >= $Info(BinLimit_Conse_${station}_${site}:${sort}) && $Info(BinLimit_Conse_${station}_${site}:${sort}) != 0 } {
#						set context "match condition Dut#$site ConseBin"
#						PutsDebug "TestResults: $context"
#						TriggerYieldMonitor $station "Dut ConseBin" $sort $site $Info(Count_ConseBin_${site})  $Info(BinLimit_Conse_${station}_${site}:${sort})
#					}
#					set Info(Last_Failbin_D${site}) $sort
#				} else {
#					set Info(Last_Failbin_D${site}) $sort
#					set Info(Count_ConseBin_${site}) 0
#				}
				
#				if { $Info(BinLimit_NonConsebins_D${site}) != 0 && $Info(BinLimit_NonConseCount_D${site}) != 0} {
#					set Info(BinLimit_NonConse_bin_${site}) ,${sort},
#					if { [string first $Info(BinLimit_NonConse_bin_${site}) $Info(BinLimit_NonConsebins_D${site})] != -1 } {
#						incr Info(BinLimit_Count_NonConse_${site})
#						if { $Info(BinLimit_Count_NonConse_${site}) > $Info(BinLimit_NonConseCount_D${site}) } {
#							set context "match condition Dut#$site BinGroup"
#							PutsDebug "TestResults: $context"
#							TriggerYieldMonitor $station "Dut BinGroup" $sort $site $Info(BinLimit_NonConseCount_D${site}) $Info(BinLimit_Count_NonConse_${site})
#						}
#					}
#				}
#			}
		}
	}
	
	if { [info exists Info(BinLimit_${station}_${site}:${sort})] && [string compare $Info(BinLimit_${station}_${site}:${sort}) "" ] != 0 } {
		if { $Info(BinCount_${station}_${site}:${sort}) > $Info(BinLimit_${station}_${site}:${sort}) && $Info(BinLimit_${station}_${site}:${sort}) != 0 } {
			if {[info exists Info(DutBinLimitTemp_${station}_$site:$sort)] && $Info(BinCount_${station}_${site}:${sort}) < $Info(DutBinLimitTemp_${station}_$site:$sort) } {
				WriteFile $YMLOG "EndOfTest: DutLimit for Site#$site Bin#$sort is $Info(DutBinLimitTemp_${station}_$site:$sort), Count:$Info(BinCount_${station}_${site}:${sort}). Hold Trigger Dut BinLimit. "
			} else {
				set context "match condition Dut#$site BinLimit"
				PutsDebug "TestResults: $context"
				TriggerYieldMonitor $station "Dut BinLimit" $sort $site $Info(BinLimit_${station}_${site}:${sort}) $Info(BinCount_${station}_${site}:${sort})
			}
		}
	}
	
	
}

###############################################################
# YieldMonitor Trigger Window. Refactoring old external prog.
# Move Trigger code into YM prog it self
###############################################################
proc TriggerYieldMonitor {station type args} {
	global Info YMLOG
	
	PutsDebug "TriggerYieldMonitor: $station $type $args"
	
	if {$Info(IgnoreGood) == 1} {
		set bin [lindex $args 0]
		if {[regexp -nocase {goodbin} $bin ]} {
			WriteFile $YMLOG "TriggerYieldMonitor: Warning: ignore good bin limits! type:$type args:$args"
			return
		}
		if {[string index $Info(PassBinList_${station}) $bin] } {
			WriteFile $YMLOG "TriggerYieldMonitor: Warning: ignore good bin limits! type:$type args:$args"
			return
		}
	}
	
	if {$Info(IsCLot) == 0 } {
		if {$Info(autoreprobe) == 0} {
# keep Info(IgnoreLot) for future disable hole lot.
			if {[info exists Info(IgnoreLot)] && $Info(IgnoreLot) == 1} {
				PutsDebug "TriggerYieldMonitor: Ignored trigger because this lot had been ignored, type $type, args $args."
			} else {
				if { ([info exists Info(IgnoreTrigger:$Info(LotID):$Info(PassNumber):$Info(WaferID))] && $Info(IgnoreTrigger:$Info(LotID):$Info(PassNumber):$Info(WaferID)) == 1) } {
					PutsDebug "TriggerYieldMonitor: Ignored trigger because this wafer had been ignored, type $type, args $args."
				} else {
# MOVE pause to CreateFailDialog			
#					evr send pause $station
					if {[string equal $type "low_yield"]} {
						set Info(TriggerSort) [lindex $args 0]
						set Info(TriggerFailure) [lindex $args 1]
						set Info(TriggerLimit) [lindex $args 2]
						set Info(trigger_label) "Bin $Info(TriggerSort) yield $Info(TriggerFailure) exceed lower yield limit $Info(TriggerLimit) "
						CreateFailDialog .alarm $station "low_yield" $Info(TriggerSort) $Info(TriggerFailure) $Info(TriggerLimit)
					} elseif {[string equal $type "high_yield"]} {
						set Info(TriggerSort) [lindex $args 0]
						set Info(TriggerFailure) [lindex $args 1]
						set Info(TriggerLimit) [lindex $args 2]
						set Info(trigger_label) "Bin $Info(TriggerSort) yield $Info(TriggerFailure) exceed high yield limit $Info(TriggerLimit) "
						CreateFailDialog .alarm $station "high_yield" $Info(TriggerSort) $Info(TriggerFailure) $Info(TriggerLimit)
					} elseif {[string equal $type "bin"]} {
						set Info(TriggerSort) [lindex $args 0]
						set Info(TriggerFailure) [lindex $args 1]
						set Info(TriggerLimit) [lindex $args 2]
						set Info(trigger_label) "Bin# $Info(TriggerSort) Count: $Info(TriggerFailure), exceed limit $Info(TriggerLimit) "	
						CreateFailDialog .alarm $station "bin" $Info(TriggerSort) $Info(TriggerFailure) $Info(TriggerLimit)
					} elseif {[string equal $type "softbin"]} {

					} elseif {[string equal $type "delta_diff"]} {
						set Info(TriggerSort) [lindex $args 0]
						set Info(TriggerFailure) [lindex $args 1]
						set Info(TriggerLimit) [lindex $args 2]
						set Info(TriggerSite) [lindex $args 3]
						set Info(trigger_label) "Bin# $Info(TriggerSort) on dut# $Info(TriggerSite) Yield: $Info(BinYield_${station}_${Info(TriggerSite)}:$Info(TriggerSort)), Min Yield(Dut#$Info(Min_Site)): $Info(Minyield_${station}_${Info(TriggerSort)}) Max Yield(Dut#$Info(Max_Site)): $Info(Maxyield_${station}_${Info(TriggerSort)}) Delta exceed Delta Limit $Info(TriggerLimit)"
						PutsDebug "into delta_diff"
						CreateFailDialog .alarm $station "delta_diff" $Info(TriggerSort) $Info(TriggerSite) $Info(TriggerFailure) $Info(TriggerLimit) $Info(Minyield_${station}_${Info(TriggerSort)}) $Info(Maxyield_${station}_${Info(TriggerSort)})

					} elseif {[string equal $type "delta_group_diff"]} {
# abandoned this elseif by JiangNan, I restruct the variable.				
#						set group_num [lindex $args 0]
#						set sort [lindex $group_num 0]
#						set site [lindex $args 1]
#						set group_bins 1Info(delta_group_${station}:${group_num}_bins)
#						set Info(trigger_label) "BinGroup# $Info(delta_group_${station}:${group_num}_bins) on dut# $site Yield: $Info(BinGroupYield_${station}_${siteno}:$group_num), Min Yield: $Info(MinGroupyield_${station}_${group_num}) Max Yield: $Info(MaxGroupyield_${station}_${group_num}) "
#						CreateFailDialog .faildelta $station "delta_group_diff" $site $group_num $Info(BinYield_${station}_${siteno}:$sort) $Info(MinGroupyield_${station}_$group_num) $Info(MaxGroupyield_${station}_$group_num)

					} elseif {[string equal $type "NoConsebins"]} {
# abandoned by JiangNan due to re-struct variable.
#						set fail_value ""
#						set Info(trigger_label) "Count_NoConse $Info(Limit_NonConsebins) Count: $Info(Count_NoConse) exceed limit $Info(Limit_NonConseCount) "
#						CreateFailDialog .alarm $station "NoConsebins" $Info(Limit_NonConsebins)  $Info(Limit_NonConseCount) $Info(Count_NoConse)
					} elseif {[string equal $type "Consebin"]} {
						set Info(TriggerSort) [lindex $args 0]
						set Info(TriggerSite) [lindex $args 1]
						set Info(TriggerFailure) [lindex $args 2]
						set Info(TriggerLimit) [lindex $args 3]
						set fail_value ""
						set Info(trigger_label) "Bin#$Info(TriggerSort) on dut#$Info(TriggerSite) Conse_Count: $Info(TriggerFailure) exceed limit $Info(TriggerLimit)  "
						CreateFailDialog .alarm $station "Consebin" $Info(TriggerSort) $Info(TriggerSite) $Info(TriggerFailure) $Info(TriggerLimit)
					} elseif {[string equal $type "Dut min yield"]} {
						set Info(TriggerSort) [lindex $args 0]
						set Info(TriggerSite) [lindex $args 1]
						set min_yield [lindex $args 2]
						set Info(TriggerLimit) $Info(BinLimit_${Info(TriggerSite)}_Min_Yield)
						set fail_value ""
						set Info(trigger_label) "Bin#$Info(TriggerSort) on Dut#$Info(TriggerSite) Low Yield: $min_yield, BinGroup: $Info(BinLimit_${Info(TriggerSite)}_BinGroup_Min) exceed limit $Info(BinLimit_${Info(TriggerSite)}_Min_Yield)  "
						CreateFailDialog .alarm $station "Dut min yield" $Info(TriggerSite) $Info(TriggerSort) $Info(BinLimit_${Info(TriggerSite)}_BinGroup_Min) $Info(BinLimit_${Info(TriggerSite)}_Min_Yield) $min_yield
					} elseif {[string equal $type "Dut max yield"]} {
						set Info(TriggerSort) [lindex $args 0]
						set Info(TriggerSite) [lindex $args 1]
						set max_yield [lindex $args 2]
						set Info(TriggerLimit) $Info(BinLimit_${Info(TriggerSite)}_Max_Yield)
						set fail_value ""
						set Info(trigger_label) "Bin#$Info(TriggerSort) on Dut#$Info(TriggerSite) High Yield: $max_yield, BinGroup: $Info(BinLimit_${Info(TriggerSite)}_BinGroup_Max) exceed limit $Info(BinLimit_${Info(TriggerSite)}_Max_Yield)  "
						CreateFailDialog .alarm $station "Dut max yield" $Info(TriggerSite) $Info(TriggerSort) $Info(TriggerLimit) $Info(BinLimit_${Info(TriggerSite)}_BinGroup_Max) $max_yield
					} elseif {[string equal $type "Dut BinLimit"]} {
						set Info(TriggerSort) [lindex $args 0]	
						set Info(TriggerSite) [lindex $args 1]
						set Info(TriggerLimit) [lindex $args 2]
						set Info(TriggerFailure) [lindex $args 3]
						set fail_value ""
						set Info(trigger_label) "Bin#$Info(TriggerSort) on Dut#$Info(TriggerSite) BinNum: $Info(TriggerFailure), exceed limit $Info(TriggerLimit)  "
						CreateFailDialog .alarm $station "Dut BinLimit" $Info(TriggerSite) $Info(TriggerSort) $Info(TriggerLimit) $Info(TriggerFailure)
					}  elseif {[string equal $type "Dut BinGroup"]} {

					}  else {
						set fail_value ""
						set Info(trigger_label) ""
						WriteFile $YMLOG "TriggerYieldMonitor: Warning: Unknown type $type, args $args, need check!"
					}
				}
			} 
			
		} else {
			PutsDebug "TriggerYieldMonitor: Ignored trigger because it is auto-reprobe session."
		}
	} else {
		PutsDebug "TriggerYieldMonitor: Ignored trigger because it is C Lot."
	}
}

###############################################################
# Store the layout of each wafer in case we need to create
# a wafermap.
###############################################################
proc EndLayoutRows {station dielist} {

	global Info

	set Info(MapConfig_${station}) $dielist
}

###############################################################
# Clear the fail counters at the start of each wafer
#
###############################################################
proc StartOfWafer {station} {
	global Info YMBIN YMLOG 

	PutsDebug "StartOfWafer: enter StartOfWafer"
	WriteFile $YMLOG  "StartOfWafer: enter StartOfWafer, initialize Info array"
# reload Limits	
#	LoadLimits
#	set Info(Count_NoConse) 0

	foreach key [array names Info] {
		set pattern "^Count_$station:(\\d+)\$"
		if [regexp $pattern $key match sort ]  {
			unset Info($key)
		}
		set pattern "^SoftBin_Count_$station:(\\d+)\$"
		if [regexp $pattern $key match sort ]  {
			unset Info($key)
		}
		set pattern "^Good_${station}_(\\d+)\$"
		if [regexp $pattern $key match dut ]  {
			unset Info($key)
		}
		set pattern "^BinCount_${station}_(\\d+):(\\d+)\$"
		if [regexp $pattern $key match dut sort ]  {
			unset Info($key)
		}
		set pattern "^Count_ConseBin:(\\d+)\$"
		if [regexp $pattern $key match dut sort ]  {
			unset Info($key)
		}
		set pattern "^Count_ConseSoftBin:(\\d+)\$"
		if [regexp $pattern $key match dut sort ]  {
			unset Info($key)
		}
#		set pattern "^DeltaGroup_$station_In(\\d+):(\\d+)\$"
#		if [regexp $pattern $key match num dut ]  {
#			unset $Info($key)
#		}
		set pattern "^Total_${station}_(\\d+):(\\d+)\$"
		if [regexp $pattern $key match dut sort ]  {
			unset Info($key)
		}
		set pattern "^BinLimit_Count_NonConse_(\\d+)\$"
		if [regexp $pattern $key match dut ]  {
			unset Info($key)
		}
	}

	set Info(TotalGood) 0
	set Info(TotalFail) 0
	set Info(Tested) 0
	set Info(MapResult_${station}) {}
	
	# reset limit monitor parameter. #comment by JiangNan, not used in this script, can't locate other place. 20150617
	#set Info(Limit_Min_Session) $Info(Limit_Min)
	
	

	foreach location $Info(Cardlayout_${station}) {
		set siteno [lindex $location 2]
		set Info(Total_${station}:$siteno) 0
		set Info(Good_${station}:$siteno) 0
		set Info(Yield_${station}:$siteno) 0.0
	}
}


###############################################################
# Create the error dialog with wafermap and recovery buttons
#
###############################################################
proc CreateFailDialog {dialog station type args} {

# limit failure site

	global Info YMAlarmDialog  YMBIN YMLOG Station Site   FailDialog Author_pass
	global YMLOGDIR TriggerLog
	
# add by Jiang, global var for trigger info.
	global Trigger
	
	PutsDebug "CreateFailDialog: $dialog $station $type $args"
	
	#set Info(IgnoreTrigger:$Info(LotID):$Info(WaferID)) 1set Info(IgnoreTrigger:$Info(LotID)) 1
	if {[info exists Info(IgnoreTrigger:$Info(LotID):$Info(PassNumber):$Info(WaferID))] && $Info(IgnoreTrigger:$Info(LotID):$Info(PassNumber):$Info(WaferID)) == 1 } {
#		WriteFile $YMLOG "CreateFailDialog: $dialog,$station,$type,$args. Ignored by Wafer Level"
		return
	}

	if {[info exists Info(IgnoreTrigger:$Info(LotID):$Info(PassNumber))] && $Info(IgnoreTrigger:$Info(LotID):$Info(PassNumber)) == 1 } {
#		WriteFile $YMLOG "CreateFailDialog: $dialog,$station,$type,$args. Ignored by Lot Level"
		return
	}
	
	if { [ winfo exists $dialog ] } {
# new request add -alarm here.	
		evr send pause $station
		focus -force $dialog
		WriteFile $YMLOG "CreateFailDialog: $dialog already exists, ignore this time($type $args), raise up $dialog."
		PutsDebug "CreateFailDialog: $dialog already exists, ignore this time($type $args), raise up $dialog."
		return
	}

	set YMAlarmDialog $dialog
	set Station $station
	
	
	# if had already been add to ignore list, just write a log.
	set trigger_failure ""
	if {[regexp -nocase {Dut} $type]} {
		set trigger_failure "Site:$Info(TriggerSite) Bin:$Info(TriggerSort) Type:$type Limit:$Info(TriggerLimit)"
	} else {
		set trigger_failure "Bin:$Info(TriggerSort) Type:$type Limit:$Info(TriggerLimit)"
	}
	if {[info exists Info(LotIgnoreFailureMode)] && [lsearch $Info(LotIgnoreFailureMode) $trigger_failure ] != -1} {	
#		WriteFile $YMLOG "$Info(Device),$Info(LotID),$Info(WaferID),$type,$Info(trigger_label), this failure mode had already been ignored by user."
		return
	} else {
#		WriteFile $TriggerLog "YieldMonitorTrigger: $Info(HOST),$Info(Device),$Info(LotID),$Info(PassNumber),$Info(WaferID),$type,TriggerLabel:$Info(trigger_label)."
		WriteFile $TriggerLog "YieldMonitorTrigger: $Info(HOST),$Info(Device),$Info(LotID),$Info(PassNumber),$Info(WaferID),$Info(ProbeCardID),$type,TriggerLabel:$Info(trigger_label)."
		WriteFile $YMLOG "YieldMonitorTrigger: $Info(HOST),$Info(Device),$Info(LotID),$Info(PassNumber),$Info(WaferID),$Info(ProbeCardID),$type,TriggerLabel:$Info(trigger_label)."
	}
	
	set s_time [ clock seconds ]
#	set d_date [ clock format [clock seconds] -format "%Y%m%d%"]

	if {[info exists Trigger]} {
		unset Trigger
	}

	set Trigger(timestamp) $s_time
	
	set date [ clock format [ clock seconds ] -format "%Y%m%d%H%M%S" ]
	if { [ string compare "low_yield" $type ] == 0 } {
		set Trigger(site) ""
		set Trigger(sort) [lindex $args 0]
		set Trigger(failure) [lindex $args 1]
		set Trigger(limit) [lindex $args 2]
	} elseif { [ string compare "high_yield" $type ] == 0 } {
		set Trigger(site) ""
		set Trigger(sort) [lindex $args 0]
		set Trigger(failure) [lindex $args 1]
		set Trigger(limit) [lindex $args 2]
	} elseif { [string compare "bin" $type ] == 0 } {
		set Trigger(site) ""
		set Trigger(sort) [lindex $args 0]
		set Trigger(failure) [lindex $args 1]
		set Trigger(limit) [lindex $args 2]
	} elseif { [string compare "softbin" $type ] == 0 } {

	} elseif { [string compare "Consebin" $type ] == 0 } {
		set Trigger(sort) [lindex $args 0]
		set Trigger(site) [lindex $args 1]
		set Trigger(failure) [lindex $args 2]
		set Trigger(limit) [lindex $args 3]
	} elseif { [string compare "NoConsebins" $type ] == 0 } {

	} elseif { [string compare "delta_diff" $type ] == 0 } {
		set Trigger(sort) [lindex $args 0]
		set Trigger(site) [lindex $args 1]
		set Trigger(failure) [lindex $args 2]
		set Trigger(limit) [lindex $args 3]
		set Trigger(min_yield) [lindex $args 4]
		set Trigger(max_yield) [lindex $args 5]
	} elseif { [string compare "delta_group_diff" $type ] == 0 } {

	} elseif { [string compare "Dut min yield" $type ] == 0 } {
		set Trigger(site) [lindex $args 0]
		set Trigger(sort) [lindex $args 1]
		set Trigger(limit) [lindex $args 2]
		set Trigger(bingroup) [lindex $args 3]
#		set Trigger(failure) [lindex $args 3]
#		set Trigger(yield) [lindex $args 4]
		set Trigger(failure) [lindex $args 4]
	} elseif { [string compare "Dut max yield" $type ] == 0 } {
		set Trigger(site) [lindex $args 0]
		set Trigger(sort) [lindex $args 1]
		set Trigger(limit) [lindex $args 2]
		set Trigger(bingroup) [lindex $args 3]
#		set Trigger(failure) [lindex $args 3]
#		set Trigger(yield) [lindex $args 4]
		set Trigger(failure) [lindex $args 4]
	} elseif { [ string compare "Dut BinLimit" $type ] == 0 } {
		set Trigger(site) [lindex $args 0]
		set Trigger(sort) [lindex $args 1]
		set Trigger(limit) [lindex $args 2]
		set Trigger(failure) [lindex $args 3]
	} elseif { [string compare "Dut BinGroup" $type ] == 0} {

	} else {
		PutsDebug "CreateFailDialog: Unkown type $type"
	}
	
	set Trigger(type) $type
	set Info(comment) ""


	
	# set Min_Session for delta limit. keep old logic
	if { [string compare "delta_diff" $type ] == 0 } {
		PutsDebug "$Info(Tested) + $Info(Min_${station})"
		if { [regexp {(\d+)%} $Info(Min_${station}) match condition ] } {
			set Info(Min_Session) [expr {$Info(Tested) + [expr $condition*$Info(TestableDie)/100 ]}]
		} else {
			set Info(Min_Session) [expr {$Info(Tested) + $Info(Min_${station})}]
		}
	}
	lappend Info(TriggerLabelHistory) $Info(trigger_label)
	lappend Info(TriggerBinHistory) $Trigger(sort)
	set NumOfTrigger 0
	foreach binNo [split $Info(TriggerBinHistory)] {
		if {$binNo == $Trigger(sort)} {
			incr NumOfTrigger
		}
	}
	
# new request to add -alarm here, by Lin Yajun, still in discussion.		
	evr send pause $station
	toplevel $dialog

	set sizes [wm maxsize .]
	set x [expr {[lindex $sizes 0]/2 - 175}]
	set y [expr {[lindex $sizes 1]/4}]

	wm geometry $dialog "+${x}+${y}"

	wm title $dialog "Bin/Delta Monitor"
	label $dialog.label
	pack  $dialog.label -side top -fill x

	frame $dialog.f3
	pack $dialog.f3 -side top -fill x

	set trigger_string "$Info(trigger_label) on $date at location $Info(LastTestedDie)"
#	lappend Trigger(history:$Info(LotID)) $trigger_string

#	global site_number
#	set site_number $site
	
	## update by fengsheng for History count.
	set cmd_lot "grep $Info(LotID) $TriggerLog | grep -v EndOfWafer | grep -v AbortLot | wc -l"
	set cmd_device "grep $Info(Device) $TriggerLog | grep -v EndOfWafer | grep -v AbortLot | wc -l"
	if [ catch { set result_lot [ eval exec "$cmd_lot" ] } err ] {
		WriteFile $YMLOG "CreateFailDialog: ERROR happen when execute $cmd_lot"
	} else {
		set counter_lot [string trim $result_lot]
	}
	if [ catch { set result_device [ eval exec "$cmd_device" ] } err ] {
		WriteFile $YMLOG "CreateFailDialog: ERROR happen when execute $cmd_device"
	} else {
		set counter_device [string trim $result_device]
	}
	

	button $dialog.f3.his1 -text "($counter_device) Trigger History Per Setup" -command {
		ShowHistory "setup"
	}
	pack   $dialog.f3.his1 -side top

	button $dialog.f3.his2 -text "($counter_lot) Trigger History Per Lot" -command {
		ShowHistory "lot"
	}
	pack   $dialog.f3.his2 -side top

	set check_file_name "$YMBIN/Failure_Mode/config.txt"
	set device $Info(Device)
	set cmd "grep $device $check_file_name | grep -i BIN${Trigger(sort)} | grep -i PASS${Info(PassNumber)} | grep -v # | head -1"
	if [catch {set result [ eval exec "$cmd" ] } err] {
		PutsDebug "Failure_Mode ERROR happen when execute $cmd, Error $err"
	} else {
		if {[string compare $result "" ] != 0} {
			set binid [lindex $result 1]
			set comparestring BIN${Trigger(sort)}
			if { [ string compare $comparestring $binid ] == 0 } {
				set mode [lindex $result 3]
				set execmd [lindex $result 4]
				set execmd "$YMBIN/Failure_Mode/$execmd"
				set tmp_result ""
				if { ! [string equal $execmd ""] } {
					if [catch {set tmp_result [ eval exec "$execmd $NumOfTrigger" ] } err] {
						set tmp_result "Error execute $execmd with errorcode: $err, Please contact Data Team check"
					}
				}
				set map "$YMBIN/Failure_Mode/$mode"
				set im [ image create photo -file $map]
				label $dialog.f3.image -image $im
				label $dialog.f3.text -text "$tmp_result"
				pack $dialog.f3.image $dialog.f3.text -side top
			}
		}
	}

	#wmap  $dialog.map -width 5i -height 5i -fg black -rotation $Info(Rotation_${station});
	wmap  $dialog.map  -fg black -rotation $Info(Rotation_${station});

	$dialog.map cat config default -bg green
	$dialog.map cat create failed -bg red
	$dialog.map cat create normal -bg green
	$dialog.map cat create test -bg SkyBlue2
	$dialog.map cat assign test T
	$dialog.map cat create skip -bg mediumorchid1
	$dialog.map cat assign skip S
	$dialog.map cat create ink -bg {pale goldenrod}
	$dialog.map cat assign ink I

#	pack $dialog.map -side top -expand yes -fill both -pady 5
	pack $dialog.map -side top -fill x -pady 5

	frame $dialog.f1
	pack  $dialog.f1 -side top -fill x

	set comment ""
	button $dialog.f1.b -text "Comment:" -anchor center -command {
		global TriggerLog Station
		set cmd "grep IgnoreTrigger $TriggerLog | grep $Info(LotID) | grep $Info(HOST)"
# later add my own. abandone old code. a little bit rabish.	
#		global Station
#		set cmd "$YMBIN/comment.sh $Info(LotID) $Info(HOST) "
		if {[ catch { set result [ eval exec "$cmd" ] } err] } {
			PutsDebug "CreateFailDialog: ERROR happen when execute $cmd, ErrorCode: $err"
		} else {
			if {[string compare $result "" ] != 0} {
				set msg ""
				foreach line [split $result "\n"] {
					if {[regexp {^.+User:(.+),.+comment:(.+) <=.+$} $line match user comment]} {					
						lappend msg "User:$user,Comment:$comment"
					}
				}
				tk_dialog .comment_his "Comment History Message" $msg info 0 "OK"
			}
		}
	}

	entry $dialog.f1.e -width 20  -textvariable Info(comment) -state normal
	pack $dialog.f1.b -in $dialog.f1 -side left -padx 10
	pack $dialog.f1.e -in $dialog.f1 -side right -fill x -expand true -padx 10
	frame $dialog.f2
	pack $dialog.f2 -side top -fill x

	button $dialog.f2.b1 -bg yellow -fg black -text "Ignore This Failure, Continue Probing" -command {
		if {[CheckComments]} {
			IgnoreTrigger "continue" 
		} else {
			return
		}
	}

	button $dialog.f2.b2 -bg yellow -fg black -text "Ignore Limits for This Wafer" -command {
		if {[CheckComments]} {
			IgnoreTrigger "wafer"
		} else {
			return
		}
	}

	button $dialog.f2.b3 -bg yellow -fg black -text "Abort Lot at End of Wafer" -command {
		global Info
		if {[CheckComments]} {
			set Info(IgnoreTrigger:$Info(LotID):$Info(PassNumber):$Info(WaferID)) 1
			AbortLot "endofwafer"
		} else {
			return
		}		
	}

	button $dialog.f2.b4 -bg yellow -fg black -text "Abort Lot Now" -command {
		if {[CheckComments]} {
			AbortLot "now"
		} else {
			return
		}		
	}

# this button only disable specific failure mode for whole lot. The button#2 above disable all the failure mode for whole wafer.
	
	button $dialog.f2.b5 -bg red -fg black -text "Disable This Failmode for This Lot" -command {
		if {[CheckComments]} {
			IgnoreTrigger "lot"
		} else {
			return
		}	
	}
	
	button $dialog.f2.b6 -bg red -fg black -text "Disable ALL YM Failmode for This Lot" -command {
		if {[CheckComments]} {
			IgnoreTrigger "all"
		} else {
			return
		}	
	}
	
	pack $dialog.f2.b1 $dialog.f2.b2 $dialog.f2.b3 $dialog.f2.b4 $dialog.f2.b5 $dialog.f2.b6 -side top -fill x -padx 10
	

	bind $dialog.f1.b <Return> {
		focus -force $dialog
	}
	
	if {[string equal $Trigger(type) "low_yield"] || [string equal $Trigger(type) "high_yield"] || [string equal $Trigger(type) "bin"]} {
		$dialog.label configure -text $Info(trigger_label)
		$dialog.map die newmap $Info(MapConfig_${station})
		if {[regexp {\+} $Trigger(sort)]} {
			foreach bin [split $Trigger(sort) "+"] {
				$dialog.map cat assign failed $bin
			}
		} elseif {[regexp -nocase {goodbin} $Trigger(sort)]} {
			set i 0
			foreach bin [split $Info(PassBinList_${station}) ""] {
				if {$bin == 0} {
					$dialog.map cat assign failed $i
				}
				incr i
			}
			unset i
		} else {
			$dialog.map cat assign failed $Trigger(sort)
		}
		$dialog.map die overlaymap $Info(MapResult_${station})
		focus -force $dialog
	} elseif {[string equal $Trigger(type) "delta_diff"]} {
		$dialog.label configure -text $Info(trigger_label)
		foreach location $Info(Cardlayout_${station}) {
			set x [lindex $location 0]
			set y [lindex $location 1]
			set siteno [lindex $location 2]
			set fail_bin $Info(BinYield_${station}_${siteno}:$Trigger(sort))
			$dialog.map die add "$x $y $siteno $fail_bin"
			if { $siteno != $Trigger(site) } {
				$dialog.map cat assign normal $siteno
				PutsDebug "siteno = $siteno, Trigger(site) = $Trigger(site)"
			} else {
				$dialog.map cat assign failed $siteno
			}			

		}
	
	} elseif {[string equal $Trigger(type) "Consebin"]} {
		$dialog.label configure -text $Info(trigger_label)
		$dialog.map die newmap $Info(MapConfig_${station})
		$dialog.map cat assign failed $Trigger(sort)
		$dialog.map die overlaymap $Info(MapResult_${station})
		focus -force $dialog
	
	} elseif {[string equal $Trigger(type) "Dut min yield"]} {
		$dialog.label configure -text $Info(trigger_label)
		foreach location $Info(Cardlayout_${station}) {
			set x [lindex $location 0]
			set y [lindex $location 1]
			set siteno [lindex $location 2]
			if {![info exists Info(Min_Yield:$siteno)]} {
				set Info(Min_Yield:$siteno) 0
			}
			set fail_bin $Info(Min_Yield:$siteno)
			$dialog.map die add "$x $y $siteno $fail_bin"
			if { [info exists Info(Max_Yield:$siteno)] && [info exists Info(BinLimit_${siteno}_Min_Yield)] &&  $Info(Min_Yield:$siteno) < $Info(BinLimit_${siteno}_Min_Yield) } {
				$dialog.map cat assign failed $siteno
			} else {
				$dialog.map cat assign normal $siteno
			}
			
		}
	} elseif {[string equal $Trigger(type) "Dut max yield"]} {
		$dialog.label configure -text $Info(trigger_label)
		foreach location $Info(Cardlayout_${station}) {
			set x [lindex $location 0]
			set y [lindex $location 1]
			set siteno [lindex $location 2]
			if {![info exists Info(Max_Yield:$siteno)]} {
				set Info(Max_Yield:$siteno) 0
			}
			set fail_bin $Info(Max_Yield:$siteno)
			
			$dialog.map die add "$x $y $siteno $fail_bin"
			if { [info exists Info(Max_Yield:$siteno)] && [info exists Info(BinLimit_${siteno}_Max_Yield)] && $Info(Max_Yield:$siteno) > $Info(BinLimit_${siteno}_Max_Yield) } {
				$dialog.map cat assign failed $siteno
			} else {
				$dialog.map cat assign normal $siteno
			}
			
		}
	} elseif {[string equal $Trigger(type) "Dut BinLimit"]} {
		$dialog.label configure -text $Info(trigger_label)
		if [ winfo exists $dialog ] {
			$dialog.label configure -text $Info(trigger_label)
			$dialog.map die newmap $Info(MapConfig_${station})
			$dialog.map cat assign failed $Trigger(sort)
			$dialog.map die overlaymap $Info(MapResult_${station})
			focus -force $dialog
		}
	} else {
		tk_dialog .error "Error" "Invalid Trigger type $Trigger(type)" warning 0 "OK"
	}

}

proc CheckComments {} {
	global Info
	if { [string length [ string trim $Info(comment) ] ] < 5 } {
		tk_dialog .warning "comment input check" "Please verify your comment inputting" warning 0 "OK"
		return 0
	}
	return 1
}

proc ShowHistory {unit} {

	global Info TriggerLog
	set cmd ""
	if {[string equal $unit "setup"]} {
		set cmd "grep $Info(Device) $TriggerLog"
	} elseif { [string equal $unit "lot"] } {
		set cmd "grep $Info(LotID) $TriggerLog"
	}
	if {[ catch { set result [ eval exec "$cmd" ] } err] } {
		PutsDebug "ShowHistory: Error in exec $cmd"
	} 
	tk_dialog .history "Show History Message" $result "" 0 "OK"
	
}

proc IgnoreTrigger {unit} {

	global Info YMAlarmDialog Trigger YMLOG Station TriggerLog YMBIN YM_TriggerHistory OLDYMLOG
	set ByPassUser [Login]
	if { [string compare $ByPassUser "0"] != 0 && [string compare $ByPassUser "failed"] != 0 } {
		if {[string equal $unit "wafer"]} {
			set Info(IgnoreTrigger:$Info(LotID):$Info(PassNumber):$Info(WaferID)) 1
#			WriteFile $YMLOG "IgnoreTrigger: $dialog,$station,$type,$args. Ignored by Wafer Level"
		} elseif {[string equal $unit "lot"] } {
			set contactstring ""
			catch { set contactstring [ eval exec "cat $YMBIN/contactlist"] }
			if { [string first $ByPassUser $contactstring] == -1 } {
				set answer [ tk_dialog .ask_permission "Disable Limit Fail" "you do not have permission!, please contact Privilege Engineer to Disable the Monitor of this Fail Bin..They are 
				$contactstring" "" 0 " OK " ]
				if { $answer == 0 } {
					return
				}
			} else {
				#set Info(IgnoreTrigger:$Info(LotID)) 1
				if {[regexp -nocase {Dut} $Trigger(type)]} {
					set FailureMode "Site:$Trigger(site) Bin:$Trigger(sort) Type:$Trigger(type) Limit:$Trigger(limit)"
				} else {
					set FailureMode "Bin:$Trigger(sort) Type:$Trigger(type) Limit:$Trigger(limit)"
				}
				lappend Info(LotIgnoreFailureMode) $FailureMode
				WriteFile $YM_TriggerHistory "IgnoreTrigger: Level:$unit,LOTID:$Info(LotID),Pass:$Info(PassNumber),FailureMode:$FailureMode."
				WriteFile $YMLOG "IgnoreTrigger: Info(LotIgnoreFailureMode) = $Info(LotIgnoreFailureMode). "
			}
		} elseif {[string equal $unit "continue"] } {
# raise up limits here, so that it won't trigger at a short time later
			PutsDebug "IgnoreTrigger: Trigger(type) is $Trigger(type)"
			if {[string equal $Trigger(type) "low_yield"]} {
				set Info(LimitMinTemp_$Trigger(sort)) [expr $Info(Tested) + $Info(Limit_Min)]
			} elseif {[string equal $Trigger(type) "high_yield"]} {
				set Info(LimitMinTemp_$Trigger(sort)) [expr $Info(Tested) + $Info(Limit_Min)]
				PutsDebug "IgnoreTrigger: LimitMinTemp is $Info(LimitMinTemp_$Trigger(sort))"
			} elseif {[string equal $Trigger(type) "bin"]} {
				if {![info exists Info(LimitTemp_$Trigger(sort))]} {
					set Info(LimitTemp_$Trigger(sort)) $Info(Limit_${Station}:$Trigger(sort))
				}
				set Info(LimitTemp_$Trigger(sort)) [expr $Info(Limit_${Station}:$Trigger(sort)) + $Info(LimitTemp_$Trigger(sort)) ]
			} elseif {[string equal $Trigger(type) "Consebin"]} {
				set Info(Count_ConseBin:$Trigger(site)) 0
			} elseif {[string equal $Trigger(type) "Dut min yield"]} {
				set Info(DutMinLimitMinTemp:$Trigger(site)) [expr $Info(Tested) + $Info(Limit_Min)]
			} elseif {[string equal $Trigger(type) "Dut max yield"]} {
				set Info(DutMaxLimitMinTemp:$Trigger(site)) [expr $Info(Tested) + $Info(Limit_Min)]
			} elseif {[string equal $Trigger(type) "Dut BinLimit"]} {
				if {![info exists Info(DutBinLimitTemp_${Station}_$Trigger(site):$Trigger(sort))]} {
					set Info(DutBinLimitTemp_${Station}_$Trigger(site):$Trigger(sort)) $Info(Limit_${Station}:$Trigger(sort))
				}
				set Info(DutBinLimitTemp_${Station}_$Trigger(site):$Trigger(sort)) [expr $Info(Limit_${Station}:$Trigger(sort)) + $Info(DutBinLimitTemp_${Station}_$Trigger(site):$Trigger(sort)) ]
				
			} else {
			
			}
		} elseif {[string equal $unit "all"]} {
			set contactstring ""
			catch { set contactstring [ eval exec "cat $YMBIN/contactlist"] }
			if { [string first $ByPassUser $contactstring] == -1 } {
				set answer [ tk_dialog .ask_permission "Disable Limit Fail" "you do not have permission!, please contact Privilege Engineer to Disable the Monitor of this Fail Bin..They are 
				$contactstring" "" 0 " OK " ]
				if { $answer == 0 } {
					return
				}
			} else {
				set Info(IgnoreTrigger:$Info(LotID):$Info(PassNumber)) 1
				WriteFile $YM_TriggerHistory "IgnoreTrigger: Level:$unit,LOTID:$Info(LotID),Pass:$Info(PassNumber)."
			}
		
		
		} else {
			tk_dialog .ask_permission "Invalid unit option" "please contact DATA TEAM Debug!! unit = $unit" ""  0  " OK " 
			return
		}
		
		set delay 0
		catch { set delay [eval exec "$YMBIN/cal_delay $Trigger(timestamp)" ] }
#		WriteFile $TriggerLog "IgnoreTrigger: $Info(HOST),$Info(Device),$Info(LotID),$Info(PassNumber),$Info(WaferID),$Trigger(type),User:$ByPassUser,Level:$unit,Delay:$delay,TriggerLabel:$Info(trigger_label),Comment:$Info(comment)"
		WriteFile $TriggerLog "IgnoreTrigger: $Info(HOST),$Info(Device),$Info(LotID),$Info(PassNumber),$Info(WaferID),$Info(ProbeCardID),$Trigger(type),User:$ByPassUser,Level:$unit,Delay:$delay,TriggerLabel:$Info(trigger_label),Comment:$Info(comment)"
		WriteFile $YMLOG "IgnoreTrigger: $Info(HOST),$Info(Device),$Info(LotID),$Info(PassNumber),$Info(WaferID),$Info(ProbeCardID),$Trigger(type),User:$ByPassUser,Level:$unit,Delay:$delay,TriggerLabel:$Info(trigger_label),Comment:$Info(comment)"
		evr send start $Station
		set context "$Info(Device),$Info(LotID),$Info(WaferID),$Info(PassNumber),Trigger Lable:$Info(trigger_label),delayed $delay, by pass by user $ByPassUser for $unit level."
		WriteFile $YMLOG "IgnoreTrigger : $context,$Info(comment), Resume integrator."
# $Info(WaferCount) still onhold to determin	
# old log for Demi.
#		set context "$Info(Device),$Info(LotID),$Info(WaferID),$Trigger(type),$Trigger(site),$Trigger(limit),$Trigger(failure),$unit,$Info(HOST),$delay,$ByPassUser,$Info(PassNumber),$Info(ProbeCardID),$Info(comment)"

		set context "$Info(Device),$Trigger(type),$Trigger(site),$Trigger(sort),$Trigger(failure),$unit,$Info(HOST),@ [clock format [clock seconds] -format "%D %T"],$delay,$ByPassUser,$Info(LotID),$Info(WaferID),$Info(PassNumber),0,$Info(ProbeCardID),$Info(comment)"
		WriteFile $OLDYMLOG "Data: $context"		
		destroy $YMAlarmDialog
	} else {
		focus -force $YMAlarmDialog
		WriteFile $YMLOG "IgnoreTrigger : User did not login successfully"
	}
	
}


proc AbortLot {when} {
	global Info YMLOG Station TriggerLog YMAlarmDialog Trigger YMBIN
	set ByPassUser [Login]
	if { [string compare $ByPassUser "0"] != 0 && [string compare $ByPassUser "failed"] != 0 } { 
#		WriteFile $YMLOG "AbortLot: $Info(HOST),$Info(Device),$Info(LotID),$Info(WaferID), User: $ByPassUser Comment: $Info(comment)"
#		WriteFile $TriggerLog "AbortLot: $Info(HOST),$Info(Device),$Info(LotID),$Info(PassNumber),$Info(WaferID),User:$ByPassUser,Comment:$Info(comment)"
		set delay 0
		catch { set delay [eval exec "$YMBIN/cal_delay $Trigger(timestamp)" ] }
		WriteFile $TriggerLog "AbortLot: $Info(HOST),$Info(Device),$Info(LotID),$Info(PassNumber),$Info(WaferID),$Info(ProbeCardID),$when,$delay,$Trigger(type),TriggerLabel:$Info(trigger_label),User:$ByPassUser,Comment:$Info(comment)"
		WriteFile $YMLOG "AbortLot: $Info(HOST),$Info(Device),$Info(LotID),$Info(PassNumber),$Info(WaferID),$Info(ProbeCardID),$when,$delay,$Trigger(type),TriggerLabel:$Info(trigger_label),User:$ByPassUser,Comment:$Info(comment)"
		if {[string equal $when "endofwafer"]} {
			evr send abortafterwafer $Station
			evr send start $Station
		} elseif {[string equal $when "now"]} {
			evr send abortlot $Station
			evr send start $Station
		} else {
			writeFile $YMLOG "AbortLot : Warning: Unknown param $when . please check!"
		}
		destroy $YMAlarmDialog
	} else {
		focus -force $YMAlarmDialog
		WriteFile $YMLOG "IgnoreTrigger : User did not login successfully"
	}
}

###############################################################
# Reset Info variables at the end-of-lot
#
###############################################################
proc EndBins_Dialog {station} {

	global Info
	if { ! [winfo exists .rusure] } {
		toplevel  .rusure
		wm title  .rusure "Stop Bin/Delta Monitor Window"

		label     .rusure.l
		pack      .rusure.l -side top -fill x

		frame     .rusure.f1
		pack      .rusure.f1 -side left -fill y -padx 10 -pady 10
		message   .rusure.f1.msg -aspect 400 -text "Please Contact a Technician Regarding Turning the Bin/Delta Monitor Off. Your Operator Id will be logged to File."
		pack      .rusure.f1.msg -side top -fill x
		button    .rusure.f1.b1 -text "Exit with No Change" -command {destroy .rusure}
		button    .rusure.f1.b2 -text "Turn Bin/Delta Monitoring Off" -command {StopMonitor $station .rusure}
		pack      .rusure.f1.b1 .rusure.f1.b2 -side bottom -fill x
	}
}

proc StopMonitor {station window} {

	global Info YMLOG YMBIN
	set ByPassUser [Login]
	if { [string compare $ByPassUser "0"] != 0 && [string compare $ByPassUser "failed"] != 0 } { 
		catch { set contactstring [ eval exec "cat $YMBIN/contactlist"] }
		if { [string first $ByPassUser $contactstring] == -1 } {
			set answer [ tk_dialog .ask_permission "Disable Limit Fail" "you do not have permission!, please contact Privilege Engineer to Disable the Monitor of this Lot ..They are 
			$contactstring" "" 0 " OK " ]
			if { $answer == 0 } {
				return
			}
		} else {
			set Info(IgnoreTrigger:$Info(LotID):$Info(PassNumber)) 1
		}
	} else {
		WriteFile $YMLOG "StopMonitor: user did not login."
	}
	PutsDebug  "StopMonitor: $ByPassUser turn off Bin/Delta Monitor."
	WriteFile $YMLOG "StopMonitor: $ByPassUser turn off Bin/Delta Monitor."

}

###############################################################
# StartOfSession 
###############################################################
proc StartOfSession {station pass} {
	global Info YMLOG
	if {![info exists Info(WaferCount)]} {
		set Info(WaferCount) 1
	} else {
		incr Info(WaferCount)
	}
	if [info exists Info(TriggerLabelHistory)] {
		unset Info(TriggerLabelHistory)
	}
	if [info exists Info(TriggerBinHistory)] {
		unset Info(TriggerBinHistory)
	}
	
	WriteFile $YMLOG "StartOfSession: incr Info(WaferCount). now is $Info(WaferCount)"
}

###############################################################
# Reset Info variables at the end-of-lot
#
###############################################################
proc EndOfLot {station} {

	global Info YMBIN FailDialog

	# End of lot OCAP check
	# comment By JiangNan.
	if {0} {
		if { $Info(Tested) >= $Info(TestableDie) && $Info(IgnoreOCAPs) == 0 } {
			set cmd "$YMBIN/AutoOCAP.eol $Info(Setup_${station}) $Info(LotID)"
			catch { eval exec $cmd }
			set exitVal 0
			set exitVal [ readFile "/tmp/eol.out" ]
			if {  $exitVal == 8  } {
				set msg "This lot has failed the Lot Lower Control Limit.\n"
				append msg "Follow your specifications for this OCAP.\n"
				set Info(IgnoreOCAPs)  [ tk_dialog .ocap "Auto OCAP's" $msg warning 0 "OK" ]
				#	evr send start $station
			}
		}
	}
	set cmd "/usr/bin/rm -f /tmp/yield.llcl /tmp/yield.wlcl /tmp/sol.out /tmp/eol.out /tmp/OCAPeow.out /tmp/OCAP.data /tmp/wafmap /tmp/outeredge /tmp/trigger_history_file "
	catch { eval exec $cmd }

	.buttonMenu.mf.sl configure -bg white -fg black -text "SL: N/A"
	.buttonMenu.mf.wcl configure -bg white -fg black -text "WLCL: N/A"
	.buttonMenu.mf.lcl configure -bg white -fg black -text "LLCL: N/A"

	set Info(Setup_${station}) "No Setup"

	LoadBinList $station
	
	## comment by fengsheng for destroy all windows.
	
	foreach value [ winfo children . ] {
		if { [ string equal $value ".buttonMenu" ] } {
		} else {
			if { [ winfo exist $value ] } {
				destroy $value
			}
		}
	}
	

	
}

proc ResetAll {station} {

	global Info
	set Info(Setup_${station}) "No Setup"
	set Info(Min_Session) 0
	set Info(Limit_NonConsebins) 0
	set Info(Limit_NonConseCount) 0
	set Info(Dut_${station}) 0
	set Info(Min_${station}) 100
	set Info(Limit_Min) 100
	set Info(BinLimit_Min) 100
	set Info(Limit_Min_Yield) 0
	set Info(Limit_Max_Yield) 0
	set Info(WaferCount) 0
	set Info(FirstWafer) 1
	set Info(Tested) 0
	set Info(TestableDie) 0
	set Info(cWaferID) N/A
	set Info(AOC_Skip) 0
	set Info(IgnoreOCAPs) 0
	set Info(GoodDie) 0
	set Info(LotID) N/A
	set Info(WaferID) N/A
	set Info(Wafer) N/A
	set Info(Pass) N/A
	set Info(RFile) N/A
	set Info(Device) N/A
	set Info(Sample) 0
	set Info(TotalGood) 0
	set Info(TotalFail) 0
	set Info(SL) 0
	set Info(WLCL) 0
	set Info(LLCL) 0
	set NoConse_bin N/A
#	set Info(Count_NoConse) 0
	set Info(disable_flag) 0
	set Info(MapResult_${station}) {}
	set Info(InPause) 0
	

	
#	Info(IgnoreTrigger:$Info(WaferID))
	LoadBinList $station
}

###############################################################
# Fill in the list of bins in the edit screen, if it is mapped
#
###############################################################
proc LoadBinList {station} {

	global Info

	if { ! [winfo exists .edit] } return

# Abandone By JiangNan because I have already changed the var structure. we did not use manually function	
#	.edit.f1.f.l delete 0 end
#	for {set i 0} {$i < 256} {incr i} {
#		if {$Info(Limit_${station}:${i}) > 0} {
#			.edit.f1.f.l insert end $i
#		}
#	}
# End

}

###############################################################
# When the user clicks on a Bin in the edit list,
# updated the Limits and Count entry widgets
###############################################################
proc ListActivated {station} {

	if [catch {set bin [.edit.f1.f.l get [.edit.f1.f.l curselection]]}] {
		return
	}
	.edit.f1.l configure -text "Bin: $bin"
	.edit.f2.e1 configure -textvariable Info(Limit_${station}:$bin)
	.edit.f2.e2 configure -textvariable Info(Count_${station}:$bin)

}

###############################################################
# Allow a user to edit the bin limits associated with a
# station.
###############################################################
proc Edit {station} {

	global Info Station

	if { ! [winfo exists .edit] } {

		set Station $station
		toplevel  .edit
		wm protocol .edit WM_DELETE_WINDOW {destroy .edit;return}

		label     .edit.l
		pack      .edit.l -side top -fill x

		frame     .edit.f1
		pack      .edit.f1 -side left -fill y -padx 10 -pady 10
		label     .edit.f1.l -text "Bin:" -anchor w -width 14
		pack      .edit.f1.l -side top -fill x
		frame     .edit.f1.f
		pack      .edit.f1.f -side top -fill both
		listbox   .edit.f1.f.l -yscrollcommand {.edit.f1.f.s set} -width 4
		pack      .edit.f1.f.l -side left -fill both -expand yes
		scrollbar .edit.f1.f.s -command {.edit.f1.f.l yview}
		pack      .edit.f1.f.s -side left -fill y

		frame     .edit.f2
		pack      .edit.f2 -side left -fill both -padx 10 -pady 10

		label     .edit.f2.l1 -anchor w -text "Limit:"
		entry     .edit.f2.e1 -width 5 -state disabled

		label     .edit.f2.l2 -anchor w -text "Count:"
		entry     .edit.f2.e2 -width 5 -state disabled

		label     .edit.f2.l3 -anchor w -text "Delta:"
		entry     .edit.f2.e3 -width 5 -state disabled

		button    .edit.f2.b1 -text "Dismiss" -command {destroy .edit}
		button	  .edit.f2.b2 -text "Stop Bin/Delta Monitoring For Current Lot" -command {EndBins_Dialog $Station}

		pack .edit.f2.l1 .edit.f2.e1 .edit.f2.l2 .edit.f2.e2 \
			.edit.f2.l3 .edit.f2.e3 -side top -fill x

		pack      .edit.f2.b1 .edit.f2.b2 -side bottom -fill x

	}

	wm deiconify .edit
	raise .edit

	wm title  .edit "Station $station Yield Limits"
	.edit.l configure -textvariable Info(Setup_${station})
	.edit.f2.e3 configure -textvariable Info(Delta_${station})
	bind .edit.f1.f.l <Button-1> "ListActivated $station"

	LoadBinList $station
}

###############################################################
# WaferInfo:  this provides information about the current wafer
# - we used testable die
###############################################################
proc WaferInfo {station wafer_id passnumber subpass xrefoffset yrefoffset yield testable zwindow} {

	global Info YMLOG 

	set Info(WaferID) [lindex [split $wafer_id "-"] 1]
	set Info(RFile) "r_$wafer_id"
	set Info(TestableDie) $testable
	set Info(PassNumber) $passnumber
	
	# if test bin table hasn't goodbin, disable Good bin yield monitor. of cause if passnumber = 1, loop out.
	#set Info(IgnoreGood) 0

	WriteFile $YMLOG "WaferInfo: Start "
	
	if {$passnumber == 1} {
	
	} else {
	    if { [info exists Info(TestBinList:$passnumber) ] } {
		set hasgoodbin 0
		foreach bin $Info(TestBinList:$passnumber) {
			if {[lindex [split $Info(PassBinList_${station}) ""] $bin] == 1} {
				set hasgoodbin 1
			}
		}
		if {$hasgoodbin == 0} {
			set Info(IgnoreGood) 1
		}
	    }
	}
	
	
# add by JiangNan for calculating "min trigger point" by percentage	for bin limit.
	if { $testable > 0} {
		if { [info exists Info(Limit_Min_Config) ] } {
			if {[regexp {(\d+)%} $Info(Limit_Min_Config) match condition ]} {
				set Info(Limit_Min) [expr $condition*$testable/100 ]
			} elseif { [regexp {^(\d+)$} $Info(Limit_Min_Config) match condition ] } {
				set Info(Limit_Min) $Info(Limit_Min_Config)
			}
		} 
		if { [info exists Info(Min_${station}_Config) ] } {
			if {[regexp {(\d+)%} $Info(Min_${station}_Config) match condition ]} {
				set Info(Min_${station}) [expr $condition*$testable/100 ]
			} elseif { [regexp {^(\d+)$} $Info(Min_${station}_Config) match condition ] } {
				set Info(Min_${station}) $Info(Min_${station}_Config)
			}
		} 
		# for percentage usage
		if { [info exists Info(Limit_PercentMin_Config) ] } {
			if {[regexp {(\d+)%} $Info(Limit_PercentMin_Config) match condition ]} {
				set Info(Limit_PercentMin) [expr $condition*$testable/100 ]
			} elseif { [regexp {^(\d+)$} $Info(Limit_PercentMin_Config) match condition ] } {
				set Info(Limit_PercentMin) $Info(Limit_PercentMin_Config)
			}
		} 
		
	} else {
		# it's strange but it really happened. testable die == 0  # by JiangNan, I think we could set some min session to default.
		set Info(Limit_Min) 100
		set Info(Limit_PercentMin) [expr 30*$testable/100 ]
		set Info(Min_${station}) 100
	}

# add by JiangNan for calculating "min trigger point" by percentage	for delta limit
	if { [regexp {(\d+)%} $Info(Min_${station}) match condition ] } {
		set Info(Min_Session) [expr $condition*$testable/100 ]
	} else {
		# reset bin delta monitoring parameters
		set Info(Min_Session) $Info(Min_${station})
	}

	PutsDebug "WaferInfo: testable dies $Info(TestableDie)"
	WriteFile $YMLOG "WaferInfo: testable dies $Info(TestableDie),Limit_Min $Info(Limit_Min), DeltaMin $Info(Min_${station}), passnumber $Info(PassNumber), wafer#$Info(WaferID)"
}

###############################################################
# End of Wafer
# Called on A5s
# Part of automatic OCAP's:
# This will take care of the N/M wafers below the scrap limit,
# opens, and current wafer below the scrap limit.
#
###############################################################
proc EndWafer {station} {

	global Info env YMBIN YMLOG 

	PutsDebug "EndWafer: WaferID: $Info(WaferID) WaferCount: $Info(WaferCount) pass: $Info(PassNumber) tested: $Info(Tested) good: $Info(TotalGood)"	
# comment by JiangNan. This part is from CHD, we did not use it, so add 0 if
	if { 0 } {
	
		set exitVal 0

		if { $Info(Tested) > 0 } {
			set Info(Yield) [ expr round ( { $Info(TotalGood) * 100.0  / $Info(Tested) } ) ]
		} else {
			set Info(Yield) 0
		}
	
	# End of wafer OCAP check
		if { $Info(Tested) >= $Info(TestableDie) && $Info(AOC_Skip) == 0 && $Info(IgnoreOCAPs) == 0 } {
			set cmd "$YMBIN/AutoOCAP.eow $Info(Setup_${station}) $Info(LotID) $Info(RFile) $Info(Yield)"
			catch { eval exec $cmd }
			set exitVal [ readFile "/tmp/OCAPeow.out" ]

			if { $Info(IgnoreOCAPs) == 0 && $Info(TestableDie) > 0 } {

				if { $exitVal != 0 } {
					evr send pause $station
					if { $exitVal == 1 } {
						set msg "3 consecutive wafers are below the Lower Control Limit."
					}
					if { $exitVal == 2 } {
						set msg "There may be too many OPENS along the edge."
					}
					if { $exitVal == 3 } {
						set msg "There may be too many OPENS along the edge, "
						append msg "and 3 consecutive wafers are below the Lower Control Limit."
					}
					if { $exitVal == 4 } {
						set msg "The previous wafer is below the SCRAP LIMIT."
					}
					if { $exitVal == 5 } {
						set msg "The previous wafer is below the SCRAP LIMIT, "
						append msg "and 3 consecutive wafers are below the Lower Control Limit."
					}
					if { $exitVal == 6 } {
						set msg "There may be too many OPENS along edge, "
						append msg "and the previous wafer is below the Scrap Limit."
					}
					if { $exitVal == 7 } {
						set msg "There may be too many OPENS along edge, "
						append msg "the previous wafer is below the wafer SCRAP LIMIT, "
						append msg "and 3 consecutive wafers are below the Lower Control Limit."
					}

					set s_time [ clock seconds ]
#					if [ catch { set time [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S" ] } ] {
#						set time N/A
#					}

					set msg1 "$Info(HOST)  @ $Info(LotID) $Info(WaferID) $msg"
					WriteFile $YMLOG "Pause: $msg1"
					set Info(IgnoreOCAPs) [ tk_dialog .ocap "Auto OCAP's" $msg warning 0 "Continue Probing" "Ignore OCAPs" "Abort Lot Now" ]
					if { $Info(IgnoreOCAPs) == 2 } {
						if { [Login "OCAP" "na" "exitVal" $exitVal "Abort Lot Now" $s_time] == 1} {
							WriteFile $YMLOG "Abort: $Info(HOST)  @ $Info(LotID) $Info(WaferID) Abort Lot Now"
						}
						evr send abortlot $station
						evr delay 100
						evr send start $station
					}
					if { $Info(IgnoreOCAPs) == 1 } {
						if { [Login "OCAP" "na" "exitVal" $exitVal "Ingore OCAPs" $s_time] == 1} {
							WriteFile $YMLOG "Resume: $Info(HOST)  @ $Info(LotID) $Info(WaferID) Ignore OCAPs"
						}
						evr send start $station
					}
					if { $Info(IgnoreOCAPs) == 0 } {
						if { [Login "OCAP" "na" "exitVal" $exitVal "Continue Probing" $s_time] == 1} {
							WriteFile $YMLOG "Resume: $Info(HOST)  @ $Info(LotID) $Info(WaferID) Continue Probing"
						}
						evr send start $station
					}
				}
			}
		}
	}


}

###############################################################
# End of Wafer for catalyst testers
###############################################################
proc EndOfWafer {station wafer_id cassette slot num_pass num_tested start_time end_time lot_id} {
	global Info env TriggerLog YMLOG
	
	set Info(Program) "N/A"
	
	WriteFile $YMLOG "EndOfWafer: now unset some Info array"
	
	set bin_msg ""
	
	foreach key [lsort -ascii [array names Info "BinCount_*"] ] {
		PutsDebug "EndOfWafer: key = $key"
		set pattern "^BinCount_${station}_(\\d+):(\\d+)\$"
		if [regexp $pattern $key match site sort ] {
			PutsDebug "EndOfWafer, key = $key site = $site sort = $sort"
			if {$Info(BinCount_${station}_${site}:${sort}) != 0} {
				set bin_msg "$bin_msg Dut$site Bin$sort Count:$Info(BinCount_${station}_${site}:${sort})|"
			}
		} else {
			PutsDebug "EndOfWafer, key = $key pattern = $pattern"
		}
		
	}
	set bin_msg [string trimright $bin_msg "|"]
	
#	set bin_msg ""
#	foreach key [array names Info] {
#		set pattern "^Count_(\\d):(\\d+)\\$"
#		if [regexp $pattern $key match station sort ]  {
#			set bin_msg "$bin_msg Bin#$sort Count $Info($key)"
#		}
#	}
#
#	set dut_msg ""
#	foreach location $Info(Cardlayout_${station}) {
#		set siteno [lindex $location 2]
#		set Info(Yield_${station}:$siteno) [expr $Info(Good_${station}:${site}) * 100.0 / $Info(Total_${station}:$siteno)]
#		set dut_msg "$dut_msg Dut#$siteno Yield: $Info(Yield_${station}:$siteno)"
#	}

	if {$Info(Tested) != 0} {
		set Info(Yield_$station) [expr $Info(TotalGood) * 100.0 / $Info(Tested)]
	} else {
		set Info(Yield_$station) 0.0
	}
	

	set GoodBin ""
	for {set i 0} {$i < [llength [split $Info(PassBinList_${station}) ""]]} {incr i} {
		if {[lindex [split $Info(PassBinList_${station}) ""] $i] == 1} {
			set GoodBin "$GoodBin+$i"
		}
	}
	set GoodBin [string trimleft $GoodBin "+"]
	
	WriteFile $TriggerLog "EndOfWafer: Device:$Info(Device),LotID:$Info(LotID),Pass:$Info(PassNumber),Wafer:$wafer_id,ProbeCard:$Info(ProbeCardID),hostname:$Info(HOST),OperatorID:$Info(OperatorID),Program:$Info(Program),Session:$Info(Session),TotalTested:$Info(Tested),PassBinList:$GoodBin,TotalYield:$Info(Yield_$station),DutBinInfo:$bin_msg ."
	WriteFile $YMLOG "EndOfWafer: Device:$Info(Device),LotID:$Info(LotID),Pass:$Info(PassNumber),Wafer:$wafer_id,ProbeCard:$Info(ProbeCardID),hostname:$Info(HOST),OperatorID:$Info(OperatorID),Program:$Info(Program),Session:$Info(Session),TotalTested:$Info(Tested),PassBinList:$GoodBin,TotalYield:$Info(Yield_$station),DutBinInfo:$bin_msg ."

# PASS:$Info(PassNumber)	
	
	if { $Info(Sample) == 0 } {
		EndWafer $station
	}
	
	foreach key [array names Info "LimitMinTemp_*"] {
		unset Info($key)
	}
	foreach key [array names Info "LimitTemp_*"] {
		unset Info($key)
	}
	foreach key [array names Info "DutMinLimitMinTemp*"] {
		unset Info($key)
	}
	foreach key [array names Info "DutMaxLimitMinTemp*"] {
		unset Info($key)
	}
	foreach key [array names Info "DutBinLimitTemp_*"] {
		unset Info($key)
	}	
	
}

###############################################################
#Error message report the yield monitor halting
###############################################################
proc ErrorMessage { station severity errno message } {
	global Info YMLOG YMBIN  TriggerLog OLDYMLOG
#	set time [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S" ]
	PutsDebug "ErrorMessage:$message"
	WriteFile $YMLOG "ErrorMessage:$message"
	if { [ regexp {^Site Result Count Monitor} $message ] || [ regexp {^Total Result Count Monitor} $message ] || [regexp {^Site Yield Monitor} $message ] || [regexp {^Pass/Fail Count Monitor} $message] || [regexp {^Total Yield Monitor} $message] } {
#		if [catch {set USER_AUTH [ eval exec "$YMBIN/login_screen" ] } err] {
#			PutsDebug "Warning_Dialog ERROR happen when execute $YMBIN/login_screen"
#		} else {
#			while { [ string last "fail" $USER_AUTH] >= 0 } {
#				set  USER_AUTH [eval exec "$YMBIN/login_screen"]
#			}
#		}
		set ByPassUser "failed"
#		set ByPassUser [Login]
#		vwait ByPassUser
		while {[string compare $ByPassUser "0"] == 0 || [string compare $ByPassUser "failed"] == 0} {
			PutsDebug "ErrorMessage login, ByPassUser = $ByPassUser"
			set ByPassUser [Login]
		}
		PutsDebug "ErrorMessage, ByPassUser = $ByPassUser"

		regsub -all {\n} $message {,} message
#		WriteFile $YMLOG "ErrorMessage: hostname:$Info(HOST),Device:$Info(Device),LotID:$Info(LotID),Pass:$Info(PassNumber),Wafer:$Info(WaferID), Navigator YM $message on , bypass by user $ByPassUser"
#		WriteFile $TriggerLog "ErrorMessage: hostname:$Info(HOST),Device:$Info(Device),LotID:$Info(LotID),Pass:$Info(PassNumber),Wafer:$Info(WaferID),Navigator YM Message:$message trigger out,ByPassUser:$ByPassUser"
		WriteFile $TriggerLog "ErrorMessage: hostname:$Info(HOST),Device:$Info(Device),LotID:$Info(LotID),Pass:$Info(PassNumber),Wafer:$Info(WaferID),ProbeCard:$Info(ProbeCardID),Navigator YM Message:$message trigger out,ByPassUser:$ByPassUser"
		WriteFile $YMLOG "ErrorMessage: hostname:$Info(HOST),Device:$Info(Device),LotID:$Info(LotID),Pass:$Info(PassNumber),Wafer:$Info(WaferID),ProbeCard:$Info(ProbeCardID),Navigator YM Message:$message trigger out,ByPassUser:$ByPassUser"
		set time [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S" ]
		WriteFile $OLDYMLOG "$Info(HOST) $time @ $Info(Device) $Info(LotID) $Info(WaferID) $ByPassUser,$message"
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
proc EndOfSession {station wafer_id cassette slot num_pass num_tested start_time end_time lot_id} {

	global Info env YMBIN YMLOG 

# Comment By JiangNan. Only CHD use this function. Useless in TJN.	
	if { 0 } {
		if { $Info(Sample) ==  1 } {

			set Info(Tested) $num_tested
			set Info(TotalGood) $num_pass

			PutsDebug $YMLOG "EndOfSession: WaferID: $Info(WaferID) WaferCount: $Info(WaferCount) pass: $Info(PassNumber) tested: $Info(Tested) good: $Info(TotalGood)"

			set exitVal 0

			if { $Info(Tested) > 0 } {
				set Info(Yield) [ expr round ( { $Info(TotalGood) * 100.0  / $Info(Tested) } ) ]
			} else {
				set Info(Yield) 0
			}

			# End of wafer OCAP check
			if { $Info(Tested) >= $Info(TestableDie) && $Info(AOC_Skip) == 0 && $Info(IgnoreOCAPs) == 0 } {
				set cmd "$YMBIN/AutoOCAP.eow $Info(Setup_${station}) $Info(LotID) $Info(RFile) $Info(Yield)"
				catch { eval exec $cmd }
				set exitVal [ readFile "/tmp/OCAPeow.out" ]

				if { $Info(TestableDie) > 0 } {

					if { $exitVal != 0 } {
						evr send pause $station
						if { $exitVal == 1 } {
							set msg "3 consecutive wafers are below the Lower Control Limit."
						}
						if { $exitVal == 2 } {
							set msg "There may be too many OPENS along the edge."
						}
						if { $exitVal == 3 } {
							set msg "There may be too many OPENS along the edge, "
							append msg "and 3 consecutive wafers are below the Lower Control Limit."
						}
						if { $exitVal == 4 } {
							set msg "The previous wafer is below the SCRAP LIMIT."
						}
						if { $exitVal == 5 } {
							set msg "The previous wafer is below the SCRAP LIMIT, "
							append msg "and 3 consecutive wafers are below the Lower Control Limit."
						}
						if { $exitVal == 6 } {
							set msg "There may be too many OPENS along edge, "
							append msg "and the previous wafer is below the Scrap Limit."
						}
						if { $exitVal == 7 } {
							set msg "There may be too many OPENS along edge, "
							append msg "the previous wafer is below the wafer SCRAP LIMIT, "
							append msg "and 3 consecutive wafers are below the Lower Control Limit."
						}

						set s_time [ clock seconds ]
#						if [ catch { set time [ clock format [ clock seconds ] -format "%Y/%m/%d %H:%M:%S" ] } ] {
#							set time N/A
#						}
						set msg1 "$Info(HOST)  @ $Info(LotID) $Info(WaferID) $msg"
						WriteFile $YMLOG "Pause: @ $msg1"
						set Info(IgnoreOCAPs) [ tk_dialog .ocap "Auto OCAP's" $msg warning 0 "Continue Probing" "Ignore OCAPs" "Abort Lot Now" ]
						if { $Info(IgnoreOCAPs) == 2 } {
							if { [Login "OCAP" "na" "exitVal" $exitVal "Abort Lot Now" $s_time] == 1} {
								WriteFile $YMLOG "Abort: $Info(HOST)  @ $Info(LotID) $Info(WaferID) Abort Lot Now"
							}
							evr send abortlot $station
							evr delay 100
							evr send start $station
						}
						if { $Info(IgnoreOCAPs) == 1 } {
							if { [Login "OCAP" "na" "exitVal" $exitVal "Ingore OCAPs" $s_time] == 1} {
								WriteFile $YMLOG "Resume: $Info(HOST)  @ $Info(LotID) $Info(WaferID) Ignore OCAPs"
							}
							evr send start $station
						}
						if { $Info(IgnoreOCAPs) == 0 } {
							if { [Login "OCAP" "na" "exitVal" $exitVal "Continue Probing" $s_time] == 1} {
								WriteFile $YMLOG "Resume: $Info(HOST)  @ $Info(LotID) $Info(WaferID) Continue Probing"
							}
							evr send start $station
						}
					}
				}
			}
		}
	}
	
	if { $Info(FirstWafer) == 1 } {
		set Info(FirstWafer) 0
	}
}

###############################################################
#	CellStatus event, add by JiangNan, for get operator id
###############################################################
proc CellStatus {station cellID label[] operatorID waferID status deviceType lotName totalWafers lastWafer runningYield waferYield[] } {
	global Info
	set Info(OperatorID) $operatorID
}

proc LotSelecTextList {station waferid action reprobeOption untestedAction binCodes} {
	# only care about last info 
	global Info YMLOG
	
	# skip any case if you choose test untested die
	if {[string equal $untestedAction "test"]} {
		return
	}
	# skip skip wafer
	if {[string equal $action "skip"]} {
		return
	}
	
	
	#disable whole lot goodbin yield monitor. when reprobe fail dice.
	set reprobelist ""
	set hasgoodbin 0
	if {[string equal $action "reprobe"]} {
		if {[string equal $reprobeOption "fail"]} {
			set Info(IgnoreGood) 1
		} elseif {[string equal $reprobeOption "bin"]} {
			if [regexp {\,} $binCodes] {
				set reprobelist [split $binCodes ","]
			} elseif [regexp {\-} $binCodes] {
				set min [lindex [split $binCodes "-"] 0]
				set max [lindex [split $binCodes "-"] 1]
				for {set i $min} { $i <= $max } {incr i} {
					lappend reprobelist $i
				}
			} else {
				# don't know why, bincodes returns like: {{1 2}}
				set reprobelist [lindex $binCodes 0]
			}
			#puts "now reprobelist = $reprobelist"
			foreach bin $reprobelist {
				if [string index $Info(PassBinList_${station}) $bin] {
					set hasgoodbin 1
				}
			}
			if {$hasgoodbin == 0} {
				set Info(IgnoreGood) 1
			}
		}
	}
	
	
	WriteFile $YMLOG "$action $reprobeOption $untestedAction $binCodes Info(IgnoreGood) = $Info(IgnoreGood),reprobelist = $reprobelist, hasgoodbin = $hasgoodbin"
	#puts "$action $reprobeOption $untestedAction $binCodes Info(IgnoreGood) = $Info(IgnoreGood),reprobelist = $reprobelist, hasgoodbin = $hasgoodbin"
}

###############################################################
#
# WriteFile
#
###############################################################
proc WriteFile { filename text } {
	set time_stamp [clock format [clock seconds] -format "%D %T"]
	set fp [open $filename "a+"]
	puts $fp "$text <= record at $time_stamp"
	close $fp
}

###############################################################
# Bin/Delta Failure Pause Logger
# User authentication use .X500 login/password
# Record necessary information for the event
#      MOO, Event type, Limit, Trigger/Bin
#      Responce, Host, Date/Time, Delay,
#      Responder, Lot, Wafer, Pass
###############################################################
proc Login {} {
	global YMBIN YMLOG Info USER_AUTH
	set Info(InPause) 1
	set USER_AUTH ""

# moved external login to inside code. to fix bug "if operator ignore fail window, yield monitor will never trigger again".
#	if [catch { set USER_AUTH [eval exec "$YMBIN/login_screen"] } err ] {
#		WriteFile $YMLOG "$err"
#		return 0
#	} else {
#		while { [string last "fail" $USER_AUTH] >= 0 } {
#			set USER_AUTH [eval exec "$YMBIN/login_screen"]
#		}
#	}
#	if {[string equal $USER_AUTH ""]} {
#		return 0
#	}
#	set Info(InPause) 0
#	return $USER_AUTH
# end. next is the new code added.

	Login_Screen
	
	vwait USER_AUTH
	
	if {![string equal "failed" $USER_AUTH]} {
		set Info(InPause) 0
	} 
	
	return $USER_AUTH

}

proc Login_Screen {} {

 	global login_name login_password Login_Screen_Name  USER_AUTH

	set screen .login
	set Login_Screen_Name $screen
	if [winfo exists $screen] return
	
	set login_name ""
	set login_password ""
	
	toplevel $screen
	wm geometry $screen "-300-400"
	wm deiconify $screen
	wm resizable $screen false false
	wm protocol $screen WM_DELETE_WINDOW { Login_Screen }
	wm title $screen "TJN-FM User Authentication Screen"

	tkwait visibility $screen
	focus -force $screen
	grab set -global $screen
	after 1000 RaiseWindow $screen

	frame $screen.row0
	label $screen.row0.l -text " Plese Enter Your OneIT Password "
	pack  $screen.row0.l -side right -padx 10 -pady 8

	frame $screen.row1
	label $screen.row1.l -text "       Login:" -anchor e
	entry $screen.row1.e -textvariable login_name -width 15
	pack  $screen.row1.e $screen.row1.l -side right -padx 6 -pady 4

	frame $screen.row2
	label $screen.row2.l -text "    Password:" -anchor e
	entry $screen.row2.e -textvariable login_password -width 15 -show *
	pack  $screen.row2.e $screen.row2.l -side right -padx 6 -pady 4

	frame  $screen.row3
	button $screen.row3.b1 -text "Cancel" -command { 
		set USER_AUTH failed
		destroy $Login_Screen_Name 
	}
	button $screen.row3.b2 -text "Confirm" -command { Show_Result $Login_Screen_Name }
	pack $screen.row3.b1 $screen.row3.b2 -side left -expand yes -fill both -padx 10 -pady 8 
	
	focus $screen.row1.e
	
	bind $screen.row1.e <Return> \
	{ 
		focus $Login_Screen_Name.row2.e
	}
	
	bind $screen.row2.e <Return> \
	{ 
		$Login_Screen_Name.row3.b2 configure -state active
		focus $Login_Screen_Name.row3.b2
	}
	bind $screen.row3.b2 <Return> { Show_Result $Login_Screen_Name }
	pack $screen.row0 $screen.row1 $screen.row2 $screen.row3 -side top
}

proc RaiseWindow { dialog } {
	global LogDir Info
	if [ winfo exists $dialog ] {
		raise $dialog
		after 1000 RaiseWindow $dialog
	}
}

proc Show_Result {screen} {
	global login_name login_password USER_AUTH YMLOG name
	set verify_passwd_prog "/exec/apps/bin/ldap/ldap_auth_fsl"
	
	if { [winfo exists $screen] } {
		destroy $screen
	}
	# YW 
	# Check point to eliminate use of probe coordinator group account
	if { [string last $login_name "r42141"] == 0 || [string last $login_name "R42141"] == 0 } {
		set msg " Invalid login name! \n\n"
		set resp [ tk_dialog .shresult " Error " $msg warning 0 "Try Again" ]
		set USER_AUTH failed
#		if { $resp == 0 } {
#			set login_name ""
#			set login_password ""
#			Login_Screen 
#		} 
	} else {
		set auth_cmd "$verify_passwd_prog $login_name $login_password"
		if { [catch {set result [eval exec $auth_cmd] } err] } {
			set msg "Error Execute cmd $verify_passwd_prog $login_name ****, please contact Data Team to check"
			WriteFile $YMLOG $msg
			set resp [ tk_dialog .shresult " Error " $msg warning 0 "OK" ]
			set USER_AUTH failed
#			if { $resp == 0 } {
#				set login_name ""
#				set login_password ""
#				Login_Screen 
#			} 
		} else {
#			set result [eval exec $auth_cmd]
			if { [string compare $result "successful"] == 0  || \
			     [string compare $result "0:Success"] == 0   || \
				 [string compare $result "200:Valid Login"] == 0 } {
				set USER_AUTH $login_name
			} else {
				set msg " Invalid login or password! \n\n Please Try Again! "
				set resp [ tk_dialog .shresult " Error " $msg warning 0 "OK"]
				set USER_AUTH failed
#				if { $resp == 0 } {
#					set login_name ""
#					set login_password ""
#					Login_Screen
#				} 
			}
		}	
	}
	
}

###############################################################
#                                                             #
# create abort dialog                                         #
#                                                             #
###############################################################
proc genabortlotfunc {title text xbmfile station} {
	global Info YMBIN Station
	evr send pause $station
	set map "$YMBIN/Failure_Mode/AbortLot.gif"
	set Station $station
	toplevel .abortlot -class Dialog
	wm title .abortlot $title
	wm iconname .abortlot Dialog
	frame .abortlot.top -relief raised -bd 1
	pack .abortlot.top -side top -fill both
	frame .abortlot.bot -relief raised -bd 1
	pack .abortlot.bot -side bottom -fill both
	set im [image create photo -file $map]
	label .abortlot.top.image -image $im
	pack .abortlot.top.image -side left -padx 5m -pady 5m	
	button .abortlot.bot.button -text OK -command {
		evr send abortlot $Station
	}
	pack .abortlot.bot.button -side left -expand 1 \
		-padx 5m -pady 5m -ipadx 2m -ipady 1m
	tkwait visibility .abortlot.bot
	focus -force .abortlot.bot.button
	
#	set answer [ tk_dialog .abortlotfunc $title $text $xbmfile 0 "  Click to ABORT LOT " ]
#	if { $answer == 0 } {
#		evr send abortlot -discard $station
#	}
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
	puts "Accept $sock from $addr $port"
	set echo(addr,$sock) [list $addr $port]
	fconfigure $sock -buffering line
	fileevent $sock readable [list Echo $sock]
}
proc Echo {sock} {
	global echo Info Trigger
	if { [eof $sock] || [catch {gets $sock line}]} {
		close $sock
		puts "Close $echo(addr,$sock)"
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

#vwait forever
# socket module over.

###############################################################
# Main Function
#
# Register ourselves with the control loop for the events
# we are interested in.
#
###############################################################

catch { set Info(HOST) [ eval exec "hostname" ] }

set Limit_File "$YM_CONFIG/limits.txt"
set Bin_Limit_File "$YM_CONFIG/bin_limits.txt"
set Dut_Limit_File "$YM_CONFIG/dut_limits.txt"
set Debug_Flag "/tmp/yield_monitor-debug_on"
set NO_OCAP_DEV "$YM_CONFIG/no_ocap_dev"
set SAMPLE_DEV "$YM_CONFIG/sample_dev"
set YMLOG "/data/probe_logs/ymbin/$HOSTNAME.log"
set OLDYMLOG "/data/probe_logs/ymbin/yield_monitor.log"
set TriggerLog "/data/probe_logs/ymbin/TriggerLog/yield_monitor_results.log"
set YM_TriggerHistory "$YMBIN/TriggerFlag/$HOSTNAME.txt"

if { ! [file exists $YM_TriggerHistory] } {
	if  [catch  {eval exec "touch $YM_TriggerHistory"}  err ] {
		tk_dialog .error "Error" "Permission Denied in create $YM_TriggerHistory, Please contact DATA TEAM check!! Error $err" warning 0 "OK"
	}
	if  [catch  {eval exec "chmod 666 $YM_TriggerHistory"}  err ] {
		tk_dialog .error "Error" "Permission Denied in create $YM_TriggerHistory, Please contact DATA TEAM check!! Error $err" warning 0 "OK"
	}
}

bind Listbox <Motion> {
	%W selection clear 0 end
	%W selection set [%W nearest %y]
}

bind Listbox <Enter> {
	%W selection clear 0 end
	%W selection set [%W nearest %y]
}

bind Listbox <Leave> {
	%W selection clear 0 end
}

option add *activeBackground orange
option add *selectBackground orange
option add *activeForeground black
option add *highlightColor orange
#set Info(ignore) 0
#set Info(stopped) 0
#set Info(autoreprobe) 0

# connect to control loop; register callback procedures
evr connect localhost
evr bind infomessage InfoMessage
evr bind testtableinfo TestTableInfo
evr bind endlayoutrows EndLayoutRows
evr bind testresults TestResults
evr bind startoflot StartOfLot
evr bind startofwafer StartOfWafer
evr bind endoflot EndOfLot
evr bind endofwafer EndOfWafer
evr bind endofsession EndOfSession
evr bind probecarddefine ProbeCardDefine
evr bind setupinfo SetupInfo
evr bind waferinfo WaferInfo
evr bind errormessage ErrorMessage
evr bind endoftest EndOfTest
evr bind setupname SetupName
evr bind startofsession StartOfSession
evr bind cellstatus CellStatus
evr bind lotselectextlist LotSelecTextList



ResetAll 0
ResetAll 1

#
# Create Startup Message
#

wm overrideredirect . true
set sizes [wm maxsize .]
set x [expr {[lindex $sizes 0]/2 - 175}]
set y [expr {[lindex $sizes 1]/2 - 70}]
wm geometry . "350x140+${x}+${y}"
label .l -bg #9478FF -bd 10 -relief raised -text " Probe Bin/Delta Monitor \n (c) 1999 - 2005 Freescale By TJNDATA"
pack .l -expand yes -fill both

after 4000 {
#	puts startup
	destroy .l
	wm withdraw .

	toplevel .buttonMenu
	wm overrideredirect .buttonMenu true
	wm geometry .buttonMenu {}

	frame .buttonMenu.lf -background white -width 20
	pack .buttonMenu.lf -expand yes -fill both
	label .buttonMenu.lf.l2 -bg #9478FF -fg white -text "Bin/Delta Monitor $VER"
	pack .buttonMenu.lf.l2 -expand yes -fill both

	frame .buttonMenu.sf -background white -width 20
	pack .buttonMenu.sf -expand yes -fill both
	button .buttonMenu.sf.b0 -width 10 -bg black -fg white -text "Station 0" -command {Edit 0}
	button .buttonMenu.sf.b1 -width 10 -bg black -fg white -text "Station 1" -command {Edit 1}
	pack .buttonMenu.sf.b0 .buttonMenu.sf.b1 -side left -expand yes -fill both

	frame .buttonMenu.mf -background white -width 20
	pack .buttonMenu.mf -expand yes -fill both
	button .buttonMenu.mf.sl -width 6 -bg white -fg black -text "SL: N/A"
	button .buttonMenu.mf.wcl -width 6 -bg white -fg black -text "WLCL: N/A"
	button .buttonMenu.mf.lcl -width 6 -bg white -fg black -text "LLCL: N/A"
	pack .buttonMenu.mf.sl .buttonMenu.mf.wcl .buttonMenu.mf.lcl -side left -expand yes -fill both

	wm geometry .buttonMenu "$YM_GEOMETRY"
	wm deiconify .buttonMenu
}

set cmd "touch $YMLOG"
catch { eval exec $cmd }

# Startup Socket Daemon
if [catch { Echo_Server $SocketPort } err ] { 
	puts "Failed startup Socket Daemon, Error: $err"
	exit 99
} else {
	puts "Success in startup Daemon	"
}
