#!/bin/sh

HOME='/exec/apps/bin/evr/OCR/etc';
[ -d $HOME ] || { echo "Missing $HOME, exiting"; exit 99; };

FILE=$HOME/ocr_write.`uname -s`
[ -x $FILE ] || { echo "Can't execute $FILE, exiting"; exit 99; };

exec $FILE "$@"
