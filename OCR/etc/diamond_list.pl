#!/usr/local/bin/perl5
use lib '/exec/apps/bin/lib/perl5';
use DBI;
use Data::Dumper;
use dbconn;
my $tbl_owner="diamond";
my ($vendor_id)=map{ /(.*)/; $1 } @ARGV;
my $dbh=DBI->connect(&getconn('tjn','diamond','read')) || die "Database connection to $tbl_owner  not made: $DBI::errstr\n";
my $sql=qq{SELECT w2s_source_lot, w2s_wafer_num, w2s_vendor_scribe FROM $tbl_owner.be_scribe_correlation where (w2s_vendor_scribe LIKE (?)) };
my ($lotid,$wfr_num,$vendor_scribe);
my $sth=$dbh->prepare($sql);
$sth->execute($vendor_id);
$sth->bind_columns(undef,\$lotid,\$wfr_num,\$vendor_scribe);
my $unit={};
$sth->fetch();
$sth->finish();
$dbh->disconnect();
$wfr_num=~s/0//g;
print "$lotid-$wfr_num";
