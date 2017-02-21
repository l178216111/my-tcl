#!/usr/local/bin/perl5
use lib '/exec/apps/bin/lib/perl5';
require LotSpec;
use POSIX qw(strftime);
my($DEV, $LOT, $WAF) = map { /(.*)/; $1 } @ARGV;
$sth=new LotSpec($DEV, $LOT);
$scribe = $sth->LotID_scribe($WAF);
$scribe="N/A" if ($scribe eq "");
print $scribe;
