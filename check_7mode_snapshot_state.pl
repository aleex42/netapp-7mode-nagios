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

__END__

=head1 NAME

check_7mode_snapshot_state.pl - Nagios Plugin - Check NetApp 7-Mode Snapshot Status

=head1 SYNOPSIS

check_7mode_snapshot_state.pl --hostname HOSTNAME --username USERNAME --password PASSWORD [--volume VOLUME]

=head1 DESCRIPTION

Checks if there are any snapshot in busy state

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp 7-Mode filer to collect the data

=item --username USERNAME

The Login Username of the monitoring-User

=item --password PASSWORD

The Login Password of the monitoring-User

=item --volume VOLUME

(OPTIONAL) The Volume name to be checked

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 if timeout occured
1 if there are any snapshots older than 90 days
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>


