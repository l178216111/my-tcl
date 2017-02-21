
/* Setuid program to write OCR data into INF tree */
/* RCS: $Id: $ */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <sys/types.h>
#include <sys/stat.h>

#define MISSING_ARGS 	99
#define ERR_NO_INF 	98
#define ERR_MKDIR 	97
#define ERR_OPEN_OCR 	96

int is_directory(char * dir); 
int is_directory_mkdir(char * dir); 

int main(int argc, char** argv)
{
     char filepath[512];
     FILE* fp;
     char* FLOOR_DATA = "/floor/data";
     char* SCDATA;

     char* DEVICE = argv[1];
     char* LOT    = argv[2];
     char* INF    = argv[3];
     char* OCR    = argv[4];

     if(argc != 5) {
	printf("Usage: ocr_write.sh DEVICE LOT FILE OCRSTRING\n");
	exit(MISSING_ARGS);
     }

     /* get SCDATA from ENV, default to /floor/data */
     SCDATA = (char *) getenv("SCDATA");
     if (SCDATA == NULL) SCDATA = FLOOR_DATA;

     /* check results_map directory exists */
     strncpy(filepath,SCDATA,512);
     strcat(filepath,"/"); strcat(filepath,"results_map");
     if (! is_directory(filepath)) {
	printf("No results_map at : %s\n",filepath);
	exit(ERR_NO_INF);
     }
 
     /* verify or mkdir DEVICE directory */
     strcat(filepath,"/"); strcat(filepath,DEVICE);
     if (! is_directory_mkdir(filepath)) {
	printf("No DEVICE at : %s\n",filepath);
	exit(ERR_MKDIR);
     }

     /* verify or mkdir LOT directory */
     strcat(filepath,"/"); strcat(filepath,LOT);
     if (! is_directory_mkdir(filepath)) {
	printf("No DEVICE at : %s\n",filepath);
	exit(ERR_MKDIR);
     }

     /* verify or mkdir .ocr directory */
     strcat(filepath,"/"); strcat(filepath,".ocr");
     if (! is_directory_mkdir(filepath)) {
	printf("No DEVICE at : %s\n",filepath);
	exit(ERR_MKDIR);
     }

     /* write OCR string */
     strcat(filepath,"/"); strcat(filepath,INF);
     fp = fopen(filepath,"w");
     if (fp == NULL) {
	printf("Cannot write ocr file: %s\n",filepath);
	exit(ERR_OPEN_OCR);
     }
     fprintf(fp, "%s\n", OCR);
     fclose(fp);
     printf("Wrote %s to %s\n", OCR, filepath);
     exit(0);
}

int is_directory(char * dir) {
     DIR* DH;

     DH = opendir(dir);
     if (DH == NULL) {
	return 0;
     } else {
	closedir(DH);
	return 1;
     }
}
int is_directory_mkdir(char * dir) {
     DIR* DH;

     DH = opendir(dir);
     if (DH == NULL) {
	mkdir(dir, 00775);
        DH = opendir(dir);
        if (DH == NULL) {
	  return 0;
	} else {
	  closedir(DH);
	  return 1;
	}
     } else {
	closedir(DH);
	return 1;
     }
}
