#!/usr/bin/perl

# --
# check_7mode_snapshot_state.pl - Check Snapshots State
# Copyright (C) 2017 Giorgio Maggiolo, http://www.maggiolo.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use strict;

use common::sense;
use NaServer;
use NaElement;
use Getopt::Long;

GetOptions (
	'hostname=s' => \my $hostname,
	'username=s' => \my $username,
	'password=s' => \my $password,
	'volume=s' => \my $volume_name,
	'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error( "$0: Error in command line arguments\n" );

sub Error {
    print "$0: ".shift;
    exit 2;
}

Error( 'Option --hostname needed!' ) unless $hostname;
Error( 'Option --username needed!' ) unless $username;
Error( 'Option --password needed!' ) unless $password;

my %busy_snapshots;

my $s = NaServer -> new ($hostname, 1, 3);
$s->set_server_type("FILER");
$s->set_transport_type("HTTP");
$s->set_style("LOGIN");
$s->set_admin_user($username,$password);

my $api = new NaElement('volume-list-info');
if($volume_name){
	$api->child_add_string('volume',$volume_name);
}

my $vol_output = $s->invoke_elem($api);

if ($vol_output->results_errno != 0) {
    my $r = $vol_output->results_reason();
    print "UNKNOWN: $r\n";
    exit(3);
}
my $volumes = $vol_output->child_get("volumes");
my @vol_result = $volumes->children_get();

foreach my $vol (@vol_result){
	my $vol_name = $vol->child_get_string("name");
	$api = new NaElement('snapshot-list-info');
	$api->child_add_string('volume',$vol->child_get_string("name"));
	my $xo = $s->invoke_elem($api);
	if ($xo->results_status() eq 'failed') {
	    my $r = $xo->results_reason();
	    print "UNKNOWN: $r\n";
	    exit(3);
	}
	my $snapshots = $xo->child_get("snapshots");
	my @snap_list = $snapshots->children_get();
	foreach my $snap (@snap_list){
		if($snap->child_get_string("busy") eq "true"){
			$busy_snapshots{$snap->child_get_string("name")} = $snap->child_get_string("dependency")." - VOL: ".$vol_name;
		}
	}
}


if (!%busy_snapshots){
    print "OK - There isn't any busy snapshot\n";
    exit 0;
} else {
    print "WARNING - There are some snapshots in busy state:\n";
        foreach my $snap (keys %busy_snapshots){
            print "$snap ($busy_snapshots{$snap})\n";
        }
    exit(1);
}