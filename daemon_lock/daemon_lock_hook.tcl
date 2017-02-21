#!/usr/local/bin/wctksh
###############################################################
#       Usage:convert test daemon mode
#       Author:LiuZX
#       Date:2016 May
#       Version:1.0
###############################################################
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
#                       set tool(pc_host) "b3j750-61"
                                if  [ catch { set tmp [ eval exec grep $tool(pc_host) $Info(hostlist) ] } err ]   {
                                         WriteFile $Info(LogFile) "get_ip: grep $tool(pc_host) in $Info(hostlist) ERROR. ERROR MSG: $err"
                                        tk_dialog .mess Error "Can't get PC IP"   {} defautl Ok
                                         exit
                                } else {
                                        set tool(pc_ip) [lindex [split $tmp | ] 1 ]
                                        regsub -all {\s}  $tool(pc_ip) "" Info(PCIP)
####### need cancel
#                                       set Info(PCIP) "10.192.153.143"
                                }
                }
        } else {
        WriteFile $Info(LogFile) "get_ip:No exist $Info(hostlist) ERROR. ERROR MSG: $err"
        puts "Can't get hostlist" 
        exit
        }
}

############################
###gen socket
############################
proc socket_client { host port comm } {
        global  Info connected
#       set timeout 5
#       after $timeout { set connected timeout}
        if [ catch {
                set sock  [ socket -async $host $port ]
                fconfigure $sock -buffering line
                puts $sock [ encoding convertto utf-8 $comm ]
        } err ]  {
                WriteFile $Info(LogFile) "socket_client:send command:$comm IP:$host ERROR. ERROR MSG: $err"
                return $err
        } else {
 #               fileevent $sock w { set connected ok }
  #              vwait connected
   #             if { $connected == "timeout" } {
#                       return "Connected timeout"
#               } else {
#               flush $sock
                gets $sock recive
                return "$recive"
#               }
        }
}
################################################
##unload program
################################################
proc change_pro {} {
        global Info 
                        set result [socket_client $Info(PCIP) 1000 "chpro"]
                        if { [ string equal $result "Change mode success"]} {
                                return  0
                        } else {
				WriteFile $Info(LogFile) $result
				return $result
                        }
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
        puts $fp "$text Part: $Info(Part) Lot: $Info(Lot) Pass: $Info(Pass) <= @ $time_stamp"
        close $fp
}
wm withdraw .
wm geometry . {}
evr connect localhost
set Info(Part) [lindex $argv 0] 
set Info(Lot) [lindex $argv 1]
set Info(Pass) [lindex $argv 2]	
set Info(home) "/exec/apps/bin/evr/daemon_lock"
set Info(HOST) [ eval exec "hostname" ]
set Info(hostlist) "/exec/apps/bin/fablots/bin/host.list"
set Info(LogFile) "/data/probe_logs/daemon_lock/daemon_lock.$Info(HOST)"
#evr send reset 0
if { [ regexp -nocase {^(GG|KK|C).*} $Info(Lot) match str ]  } {
	WriteFile $Info(LogFile) "No production lot skip"
	puts "No production lot skip convert mode"
} else {
	WriteFile $Info(LogFile) "Production lot,need check Daemon Mode"	
	puts "production lot convert mode to pro"
	if { [file exists "/tmp/$Info(HOST)_ENG" ] } {
	WriteFile $Info(LogFile) "production lot need change to pro mode"
#send command to Daemon_lock evr
		set result [socket_client $Info(HOST) 9900 {cmd  debug_command chpro}]	
#		puts $result
		if {[string compare $result 0] ==0 } {
		puts "convert mode failed"
			exit 9
		}
	}
}
exit 
