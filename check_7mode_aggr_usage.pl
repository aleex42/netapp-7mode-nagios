#!/usr/bin/perl

# --
# check_7mode_aggr_usage.pl - Check NetApp System Aggregate Space Usage (real allocated blocks)
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use strict;
use warnings;

use lib "/usr/lib/netapp-manageability-sdk-5.1/lib/perl/NetApp";
use NaServer;
use NaElement;
use Getopt::Long;

GetOptions(
	'hostname=s' => \my $Hostname,
	'username=s' => \my $Username,
	'password=s' => \my $Password,
	'warning=i' => \my $Warning,
	'critical=i' => \my $Critical,	
	'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . shift;
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;
Error('Option --warning needed!') unless $Warning;
Error('Option --critical needed!') unless $Critical;

my $s = NaServer->new ($Hostname, 1, 3);

$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user($Username, $Password);
$s->set_timeout(60);

my $output = $s->invoke("aggr-space-list-info");

my $aggrs = $output->child_get("aggregates");
my @result = $aggrs->children_get();

my $warning_aggrs = 0;
my $critical_aggrs = 0;
my $message;

foreach my $aggr (@result){

	my $aggr_name = $aggr->child_get_string("aggregate-name");
	my $aggr_alloc = $aggr->child_get_int("size-volume-allocated");
	my $aggr_free = $aggr->child_get_string("size-free");
	my $aggr_used = $aggr->child_get_string("size-volume-used");

	my $size = $aggr_alloc+$aggr_free;
	my $percent = $aggr_used/$size*100;
        my $percent_rounded = sprintf("%.2f", $percent);

	if($percent>=$Critical){
		$critical_aggrs++;
	} elsif ($percent>=$Warning){
		$warning_aggrs++;
	} 

	if($message){
        	$message .= ", " . $aggr_name . " (" . $percent_rounded . "%)";
	} else {
		$message .= $aggr_name . " (" . $percent_rounded . "%)";
	}
}

if($critical_aggrs > 0){
        print "CRITICAL: " . $message . "\n";
        exit 2;
} elsif($warning_aggrs >0){
	print "WARNING: " . $message . "\n";
	exit 1;
} else {
        print "OK: " . $message . "\n";
        exit 0;
}

