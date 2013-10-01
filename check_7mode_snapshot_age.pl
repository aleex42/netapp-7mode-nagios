#!/usr/bin/perl

# --
# check_7mode_snapshot_age.pl - Check NetApp System Snapshot Age
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
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error("$0: Error in command line arguments\n");

sub Error {
    print "$0: " . shift;
    exit 2;
}
Error('Option --hostname needed!') unless $Hostname;
Error('Option --username needed!') unless $Username;
Error('Option --password needed!') unless $Password;

my $maxtime = 90*24*3600; # 7776000 (90 days)
my $sched_maxtime;
my $now = time;
my $old = 0;
my $old_snapshots;

my $s = NaServer->new ($Hostname, 1, 3);

$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user($Username, $Password);

my $vol_output = $s->invoke("volume-list-info");

if ($vol_output->results_errno != 0) {
    my $r = $vol_output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $volumes = $vol_output->child_get("volumes");
my @vol_result = $volumes->children_get();

foreach my $vol (@vol_result){

    my $vol_name = $vol->child_get_string("name");

    my $sched_api = new NaElement('snapshot-get-schedule');
    $sched_api->child_add_string('volume',$vol_name);
    my $sched_output = $s->invoke_elem($sched_api);

    if ($sched_output->results_errno != 0) {
        my $r = $sched_output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
    }

    my $nightly_sched;
    my $weekly_sched;

    if($sched_output->child_get_string("days") && $sched_output->child_get_string("weeks")){

        $nightly_sched = $sched_output->child_get_string("days");
        $weekly_sched = $sched_output->child_get_string("weeks");

        if($nightly_sched != 0){
            $sched_maxtime = $nightly_sched*24*3600;
        }
        if($weekly_sched != 0){
            $sched_maxtime = $weekly_sched*7*24*3600;
        }

    } else {
        $sched_maxtime = $maxtime;
    }

    my $api = new NaElement('snapshot-list-info');
    $api->child_add_string('volume',$vol_name);
    my $snapshot_output = $s->invoke_elem($api);

    if ($snapshot_output->results_errno != 0) {
        my $r = $snapshot_output->results_reason();
        print "UNKNOWN: $r\n";
        exit 3;
    }

    my $snapshots = $snapshot_output->child_get("snapshots");

    if($snapshots){

        my @snap_result = $snapshots->children_get();

        foreach my $snapshot (@snap_result){

            my $snap_name = $snapshot->child_get_string("name");
            my $snap_time = $snapshot->child_get_string("access-time");
            my $age = $now - $snap_time;

            if($snap_name =~ m/^(hourly|nightly|weekly)\./){
                if($vol_name !~ m/^snapmirror/){
                    if($age > $sched_maxtime){
                        $old++;
                        if($old_snapshots){
                            $old_snapshots .= ", $vol_name/$snap_name";
                        } else {
                            $old_snapshots = "$vol_name/$snap_name";
                        }
                    }
                }
            } else {
                if($age >$maxtime){
                    $old++;
                    if($old_snapshots){
                        $old_snapshots .= ", $vol_name/$snap_name";
                    } else {
                        $old_snapshots = "$vol_name/$snap_name";
                    }
                }
            }
        }
    }
}

if($old ne "0"){
    print "$old dead snapshot(s) older than 90 days:\n";
    print "$old_snapshots\n";
    exit 1;
} else {
    print "No dead snapshots older than 90 days\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_7mode_snapshot_age.pl - Nagios Plugin - Check NetApp 7-Mode Snapshot Age

=head1 SYNOPSIS

check_7mode_snapshot_age.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD

=head1 DESCRIPTION

Checks if there are any snapshots older than 90 days 

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp 7-Mode filer to collect the data

=item --username USERNAME

The Login Username of the monitoring-User

=item --password PASSWORD

The Login Password of the monitoring-User

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


