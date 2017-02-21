gcc gpib_tcl.c -o gpib_tcl -L/exec/apps/sun4u_local/bin/TCLTK8.3.4/lib -ltcl8.3 -shared -lgpib -fPIC
#include <sys/ugpib.h>
#include </opt/NICgpib/cib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include </exec/apps/sun4u_local/bin/TCLTK8.3.4/include/tcl.h>

int Device = 0;
char ibrsp_re;
char ibrd_str[1024];
int BoardIndex = 0;
int PrimaryAddress = 0;
int SecondaryAddress = 0;
char *command_value;

int Tcl_ibwrt(ClientData notUsed, Tcl_Interp *interp, int argc, char **argv)
{
        int PrimaryAddress = atoi(argv[1]);
        Device = ibdev(BoardIndex,PrimaryAddress,SecondaryAddress,8,1,0);

        if (ibsta & ERR) {
        	printf("%s","ibdev Error");
        	Tcl_SetResult(interp, "ibdev Error", TCL_VOLATILE);
		ibonl (Device,1);
        	return TCL_ERROR;
        }

        if ( ibclr(Device) & ERR)
        {
        printf("%s","ibclr Error");
	ibonl (Device,1);
        Tcl_SetResult(interp, "ibclr Error", TCL_VOLATILE);
        return TCL_ERROR;
        }
	fflush(stdin);
	command_value = argv[2];	
	ibwrt(Device,strcat(command_value,"\r\n"),strlen(command_value)+4);	
	if (ibsta & ERR) {	
        	printf("%s","ibwrt Error");
        	Tcl_SetResult(interp, "ibwrt Error", TCL_VOLATILE);
		ibonl (Device,1);
        	return TCL_ERROR;
        }
        if (ibtrg(Device) & ERR) {
        	printf("%s","ibtrg Error");
        	Tcl_SetResult(interp, "ibdev Error", TCL_VOLATILE);
        	return TCL_ERROR;
        }
	if (ibrsp(Device, &ibrsp_re) & ERR ) {
        	printf("%s","ibrsp Error");
        	Tcl_SetResult(interp, "ibrsp Error", TCL_VOLATILE);
		ibonl (Device,1);
        	return TCL_ERROR;
	}
        if (ibrd (Device,ibrd_str,20L) & ERR) {
        ibonl (Device,1);
        ibclr (Device);
        printf("%s","ibrd Error");
        Tcl_SetResult(interp, "ibrd Error", TCL_VOLATILE);
        return TCL_ERROR;
        }
        ibonl (Device,1);
        printf("Reading: %s\n", ibrd_str);
        Tcl_SetResult(interp, ibrd_str, TCL_VOLATILE);
	return TCL_OK;
}
int Gpib_tcl_Init(Tcl_Interp *Interp) {
	Tcl_CreateCommand (Interp, "ibwrt",(Tcl_CmdProc *)Tcl_ibwrt, (ClientData)0, 0);
	return TCL_OK;
}

