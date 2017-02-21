#!/usr/local/bin/wctksh_3.2
#
set EWM_SITE TJN
set TriggerFilePath "/floor/data/ewm_trigger"
#set TriggerFilePath "/tmp"


####################################################################################
# writes into a file                                                               #
####################################################################################
proc WriteFile {filename text} {
	set fp [open $filename "a+"]
	puts $fp $text
	close $fp
}

####################################################################################
# gets the Env Variable of variable                                                #
# returns "not set" if unavailable                                                 #
####################################################################################
proc get_env {variable} {
	global env

	foreach var [array names env] {
		if { [string compare $var $variable] == 0 } {
			return $env($var)
		}
	}
	return "not set"
}

####################################################################################
# called if conb2b failed in WriteResults; touch a flag for reloading data later   #
####################################################################################
proc Reconv_Later {} {
	global env Info LogFile ErrFile Debug_Flag

	set scfcmount [get_env SCFCMOUNT]
	if { [string compare $scfcmount "not set"] == 0 } {
		WriteFile $ErrFile "Reconv_Later ERROR Env Var SCFCMOUNT not set"
		set scfcmount "/floor"
	} else {
		if [file exists $Debug_Flag] {
			WriteFile $LogFile "Reconv_Later scfcmount $scfcmount"	
		}
	}

	set reconv_path "$BinDir/recon/$Info("Ture_device")_$Info("lotid")_$Info("Wafer")"
	set context "$scfcmount:$Info("Red_Bad_Bin_Code"):$Info("Red_Good_Bin_Code")"

	if { [catch {open $reconv_path a+} fid] } {
		WriteFile $ErrFile "Reconv_Later $fid"
		return 0
	} else {
		puts $fid $context
		close $fid
		if [file exists $Debug_Flag] {
			WriteFile $LogFile "Reconv_Later path $reconv_path"
		}
		return 1
	}
}

####################################################################################
# gets the device name from setup message                                          #
####################################################################################
proc GetDeviceName {station message} {
	global Info LogFile ErrFile LclDir BinDir OeeFileDir Debug_Flag Red_Bin_Conf_File Red_Bin_Conf_Prim Red_Bin_Conf_Seco Red_Bin_Seco_Lots

	if [regexp {^Reading setup ([^ ]+)} $message match setup] {
		set Info("Ture_Device") [string toupper $setup]
		set Info("Ture_device") [string tolower $setup]
		set tempVab [string range $Info("LotID") 0 1]
                if { [string compare $tempVab "TT"] == 0  || [string compare $tempVab "TP"] == 0 } {
                        # YW
                        # Need to strip out -M, -N from setup names for CHD multi-site devices
                        if [regexp {\-(M|N)$} $setup match] {
                                regexp {(.+)-(M|N)$} $setup match Info("Device")
                        } else {
                                set Info("Device") $setup
                        }
		}
		set Red_Bin_Conf_File $Red_Bin_Conf_Prim
                regexp {(.+)\..} $Info("LotID") match LOTparent
		
		if [file exists $Red_Bin_Seco_Lots ] {
                	# Change Red_Bin_Conf_File if the lot is in the list of secondary lots
                	set cmd "grep $LOTparent $Red_Bin_Seco_Lots | head -1"

                	if [file exists $Debug_Flag] {
                        	WriteFile $LogFile "GetDeviceName executing $cmd"
                	}
                	if { [catch {eval exec $cmd} err] } {
                        	WriteFile $ErrFile "GetDeviceName ERROR cannot load data: $err"
                	} else {
                               	set Red_Bin_Conf_File $Red_Bin_Conf_Seco
                        	if [file exists $Debug_Flag] {
                                	WriteFile $LogFile "GetDeviceName config file changed to $Red_Bin_Conf_File"
                        	}
                	}
		}

		# Loading Redundancy Bin Configuration
                if [file exists $Red_Bin_Conf_File] {
                        if [ catch {set MOO [eval exec "$BinDir/find_moo_redbin $Info("Ture_Device") $Red_Bin_Conf_File"]} err] {
                                if [file exists $Debug_Flag] {
                                        WriteFile $LogFile "GetDeviceName_RedBin Error finding device"
                                }
                                set Info("Red_Bad_Bin_Code") 0
                                set Info("Red_Good_Bin_Code") 0
                                set Info("Red_Bin_Limit") 0
                        } else {
                                if [file exists $Debug_Flag] {
                                        WriteFile $LogFile "GetDeviceName_RedBin Matching Device found: $MOO"
                                }
                                if { [ string compare $MOO "NONE" ] == 0 } {
                                        if [file exists $Debug_Flag] {
                                                WriteFile $LogFile "GetDeviceName_RedBin No matching device found"
                                        }
                                        set Info("Red_Bad_Bin_Code") 0
                                        set Info("Red_Good_Bin_Code") 0
                                        set Info("Red_Bin_Limit") 0
                                } else {
					set handle [open "$Red_Bin_Conf_File"]
					inf iconfig
					iconfig load $handle
					close $handle

					if [catch { set isetup [iconfig blocks -unique $MOO] }] {
						if [file exists $Debug_Flag] {
                                                        WriteFile $LogFile "GetDeviceName_RedBin Cannot read config for $MOO"
                                                }
						set Info("Red_Bad_Bin_Code") 0
						set Info("Red_Good_Bin_Code") 0
						set Info("Red_Bin_Limit") 0
					} else {
						if [catch { set Info("Red_Bad_Bin_Code") [$isetup data -noerror old_bin] } ] {
							if [file exists $Debug_Flag] {
                                                        	WriteFile $LogFile "GetDeviceName_RedBin Cannot read old bin info"
                                                	}
							set Info("Red_Bad_Bin_Code") 0	
						}
						if [catch { set Info("Red_Good_Bin_Code") [$isetup data -noerror new_bin] } ] {
                                                	if [file exists $Debug_Flag] {
                                                        	WriteFile $LogFile "GetDeviceName_RedBin Cannot read new bin info"
                                                	}
							set Info("Red_Good_Bin_Code") 0	
						}
						if [catch { set Info("Red_Bin_Limit") [$isetup data -noerror limit] } ] {
                                                	if [file exists $Debug_Flag] {
                                                        	WriteFile $LogFile "GetDeviceName_RedBin Cannot read limit info"
                                                	}
							set Info("Red_Bin_Limit") 0
						}
					}
				}
			}
		}

		if [file exists $Debug_Flag] {
			WriteFile $LogFile "GetDeviceName Redundancy Bin Info: Bad Bin Code $Info("Red_Bad_Bin_Code"); Good Bin Code $Info("Red_Good_Bin_Code"); Limit $Info("Red_Bin_Limit")"
		}

	}
}

####################################################################################
# get the lot number from setup info                                               #
####################################################################################
proc GetLotNumber {station wsize xsize ysize xref yref flat rotation yldhi yldlo lotid} {
	global Info LogFile

	set Info("LotID") [string toupper $lotid]
	set Info("lotid") [string tolower $lotid]
}

####################################################################################
# provides information about the current wafer                                     #
####################################################################################
proc GetWaferInfo {station wafer_id passnumber subpass xrefoffset yrefoffset yield testable zwindow} {
	global Info LogFile LclDir BinDir ErrFile Debug_Flag

	set Info("WaferID") $wafer_id
	set Info("Pass") $passnumber
	
	if [regexp {\-([^ ]+)} $wafer_id match wafer] {
		set Info("Wafer") $wafer
	} 
}

####################################################################################
# called at the end of each touch down                                             #
####################################################################################
proc EndOfTest {station x y site test bin sort} {
	global Info Debug_Flag LogFile
	
	# Redundancy Bin Converting
	if { $Info("Red_Bad_Bin_Code") != 0 && $Info("Red_Good_Bin_Code") != 0 } {
	 	if { $sort == $Info("Red_Bad_Bin_Code") } {
			incr {Info("Red_Bin_Num")}
			if [file exists $Debug_Flag] {
				WriteFile $LogFile "EndOfTest total number of bin $Info("Red_Bad_Bin_Code"): $Info("Red_Bin_Num")"
			}
		}
	}
}	
	
####################################################################################
# called to generate INF trigger file for EWM in WriteResults                      #
####################################################################################
proc EWM_Trigger {type path} {
        global Info LogFile Debug_Flag TriggerFilePath TriggerFileInPath Alt_TriggerFilePath EWM_SITE

        # YW
        # %Y does not work for SunOS4 or earlier platform
        # set timestamp [ eval exec "date +%Y%m%d%H%M%S" ]
        set timestamp [ eval exec "date +20%y%m%d%H%M%S" ]

        if { [string compare $EWM_SITE "CHD"] == 0 } {
                if [regexp {\-(M|N)/} $path match] {
                        if [file exists $Debug_Flag] {
                                WriteFile $LogFile "ewm_trigger.EWM_Trigger Old INF path: $path"
                        }
                        regsub "^(.+)\-(M|N)/(.+)$" $path {\1/\3} path
                        if [file exists $Debug_Flag] {
                                WriteFile $LogFile "ewm_trigger.EWM_Trigger New INF path: $path"
                        }
                }
        }

        set context "LayoutId=$Info("Device"),LotId=$Info("LotID"),SlotNumber=$Info("Wafer"),MapName=Pass$Info("Pass"),File=$path"

        if { $type == 0 } {

                set TriggerFileTemp "$TriggerFilePath/.incoming"
                if { ! [file isdirectory "$TriggerFileTemp"] } { file mkdir "$TriggerFileTemp" }
                if { ! [file isdirectory "$TriggerFileTemp"] } {
                        WriteFile $LogFile "ewm_trigger.EWM_Trigger error creating Trigger handoff dir ($TriggerFileTemp)"
                        return 0
                }
                set ewm_trigger_temp "$TriggerFileTemp/$Info("lotid").$Info("Wafer")_$timestamp.txt"
                set ewm_trigger_path "$TriggerFilePath/$Info("lotid").$Info("Wafer")_$timestamp.txt"

        } else {
                set ewm_trigger_temp "$Alt_TriggerFilePath/$Info("lotid").$Info("Wafer")_$timestamp.txt"
                set ewm_trigger_path $ewm_trigger_temp
        }

        if { [catch {open $ewm_trigger_temp a+} fid] } {
                WriteFile $LogFile "ewm_trigger.EWM_Trigger error writing Trigger file (fid:$fid) (file:$ewm_trigger_temp)"
                return 0
        } else {
                puts $fid $context
                close $fid

                if { $type == 0 } {  file rename $ewm_trigger_temp $ewm_trigger_path }

                if [file exists $Debug_Flag] {
                        set cmd "ls -l $ewm_trigger_path"
                        set fid [open "|$cmd"]
                        set ls [gets $fid]
                        close $fid

                        WriteFile $LogFile "ewm_trigger.EWM_Trigger file $ls"
                        WriteFile $LogFile "ewm_trigger.EWM_Trigger context $context"
                }
                return 1
        }
}

####################################################################################
# initialize elements in Info                                                      #
####################################################################################
proc Reset_Info {} {
	global Info LclDir BinDir ProbeCardUsageLimit

	set Info("Device") N/A
	set Info("Ture_Device") N/A
	set Info("device") n/a
	set Info("Ture_device") n/a
	set Info("LotID") N/A
	set Info("lotid") n/a
	set Info("WaferID") N/A
	set Info("Wafer") N/A
	set Info("Pass") N/A
	set Info("Red_Bad_Bin_Code") 0
	set Info("Red_Good_Bin_Code") 0
	set Info("Red_Bin_Num") 0
	set Info("Red_Bin_Limit") 0
	
}

####################################################################################
# Loading data into synergy after results map has been updated                     #
####################################################################################
proc WriteResults {station path file} {
	global Info LogFile ErrFile LclDir BinDir Debug_Flag PCTRFile ProbeCardUsageLimit

	set scfcmount [get_env SCFCMOUNT]	
	if { [string compare $scfcmount "not set"] == 0 } {	
 		set scfcmount "/floor"
	}
	# Script to run bin conversion for redundancy bin
	if { $Info("Red_Bad_Bin_Code") != 0 && $Info("Red_Good_Bin_Code") != 0 && $Info("Red_Bin_Limit") != 0 } {
	  	if { $Info("Red_Bin_Num") != 0 && $Info("Red_Bin_Num") <= $Info("Red_Bin_Limit") } {
	 	 	set data_dir $scfcmount/data/results_map
	 	# 	set data_dir $BinDir/testdata
	 	 	set timer "$BinDir/Timer"
	 	 	set prog "$timer $path/$file $BinDir/conb2b"
	 	 	if [file exists $Debug_Flag] {
	 	 		WriteFile $LogFile "WriteResults executing $prog $data_dir $Info("Ture_Device") $Info("LotID") $Info("Wafer") $Info("Red_Bad_Bin_Code") $Info("Red_Good_Bin_Code")"	
	 	 	}
	 	 	set conv_cmd "$prog $data_dir $Info("Ture_Device") $Info("LotID") $Info("Wafer") $Info("Red_Bad_Bin_Code") $Info("Red_Good_Bin_Code") "
	 	 	if { [catch {eval exec $conv_cmd} err] } {
	 	 		if [file exists $Debug_Flag] {
	 	 			WriteFile $LogFile "WriteResults ERROR when executing $conv_cmd: $err"
	 	 		}
	 	 		Reconv_Later
	 	 	} else {
	 	 		if [file exists $Debug_Flag] {
	 	 			WriteFile $LogFile "WriteResults executing $conv_cmd completed"
	 	 		}
	 	 	}	
 	 	}
		#####add for transfer data from INF(floor/data) to Dbox place by Tanya####
		set inf_tran_cmd " $BinDir/Beprobe /custom/EOW/INFProc.pl $Info("Ture_Device") $Info("LotID") $Info("Pass") $Info("Wafer") $station "
		if { [ catch { eval exec $inf_tran_cmd} err] } {
				if [file exists $Debug_Flag] {
                                        WriteFile $LogFile "Transfer INF  ERROR when executing $inf_tran_cmd: $err"
                                }
		} else {
			if [file exists $Debug_Flag] {
                                        WriteFile $LogFile "Transfer INF  executing $inf_tran_cmd completed"
                                }
                        }
		####add end by Tanya#####

	        #####add for re-trigger ewm after repair bin############

       		EWM_Trigger 0 $path/$file

        	####add end by Tanya


 	 	set Info("Red_Bin_Num") 0
	}
}

####################################################################################
# Main Function                                                                    #
#                                                                                  #
# Register ourselves with the control loop for the events                          #
# we are interested in.                                                            #
#                                                                                  #
####################################################################################
set evrdir "/exec/apps/bin/evr"
set BinDir "$evrdir/redbin"
set LogFile "/tmp/red_bin_conv.out"
set ErrFile "/tmp/red_bin_conv.err"
set Debug_Flag "/tmp/evr_debug_on"
set Red_Bin_Conf_Prim "$BinDir/red_bin_config.txt"
set Red_Bin_Conf_Seco "$BinDir/red_bin_config.secondary"
set Red_Bin_Seco_Lots "$BinDir/secondary_red_bin_lots"

Reset_Info

#
# connect to control loop; register callback procedures
#
evr connect localhost
evr bind infomessage GetDeviceName
evr bind setupinfo GetLotNumber 
evr bind waferinfo GetWaferInfo
evr bind testresults EndOfTest
evr bind resultsmapupdate WriteResults

set Info("HOSTNAME") [ eval exec "hostname" ]

#
# Create Startup Message
#
wm overrideredirect . true
set sizes [wm maxsize .]
set x [expr {[lindex $sizes 0]/2 - 175}]
set y [expr {[lindex $sizes 1]/2 - 70}]
wm geometry . "350x140+${x}+${y}"

label .l -bg lightblue -fg red -bd 10 -relief raised -text " Redundancy Bin Convertor \n (c) 2006 Freescale"
pack .l -expand yes -fill both

after 4000 {
	destroy .l
	wm withdraw .
}
