#!/usr/local/bin/perl5
use Net::LDAP;
my ($usrname,$password)=map{ /(.*)/; $1 } @ARGV ;
$usrname=~ s/\s//g;
$ldaps_url = 'ldaps://fsl-ids.freescale.net:636';       # SSL 
$ldap = Net::LDAP->new( $ldaps_url ) or die "999:$! ($@)\n";
$user_dn = "motguid=".$usrname.",ou=people,ou=intranet,dc=motorola,dc=com";
$mesg = $ldap->bind( $user_dn, password => $password );
$ldap->unbind;
if ($mesg->code==0){
#success
	print 1;
} else {
#fail
	print 0;
}
