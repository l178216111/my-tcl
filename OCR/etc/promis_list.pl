#!/usr/local/bin/perl5
use lib '/exec/apps/bin/lib/perl5';
require '/exec/apps/bin/evr/OCR/etc/env_unix.pm';
use DBI;
require "/exec/apps/bin/lib/perl5/dbconn.pm";
my ($lot,$tmp)=map{ /(.*)/; $1 } @ARGV;
die "Not Lot Input" if $lot eq "";
my $dbh=DBI->connect(&getconn('tjn','promis','read')) or die $!;
my $sql=qq{select COMPIDS from ACTLCOMPCOUNT where LOTID='$lot' and  COMPSTATE='01'};
my $sth=$dbh->prepare($sql) or die $!;
$sth->execute() or die $!;
$sth->bind_columns(
	undef,\$compid
);
my @promis_list;
while ($sth->fetch() ) {
	my $str=$compid;
	my @tmp=split (/\./ ,$str);
	push @promis_list,$tmp[1];
}
$dbh->disconnect() or die $!;
print join(",",@promis_list);
