#!/usr/bin/perl

# --
# check_7mode_vol_usage.pl - Check NetApp System Volume Space Usage
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
    'volume=s' => \my $Volume,
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
Error('Option --volume needed!') unless $Volume;
Error('Option --warning needed!') unless $Warning;
Error('Option --critical needed!') unless $Critical;

my $s = NaServer->new ($Hostname, 1, 3);

$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user($Username, $Password);
$s->set_timeout(60);

my $output = $s->invoke("volume-list-info", "volume", $Volume);

if ($output->results_errno != 0) {
    my $r = $output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $vols = $output->child_get("volumes");
my @result = $vols->children_get();

foreach my $vol (@result){

    my $used = $vol->child_get_int("percentage-used");

    if($used>=$Critical){
        print "CRITICAL: $Volume ($used%)\n";              
         exit 2;
    } elsif ($used>=$Warning){
        print "WARNING: $Volume ($used%)\n";
        exit 1;
    } else {
        print "OK: $Volume ($used%)\n";
        exit 0;
    }
}


__END__

=encoding utf8

=head1 NAME

check_7mode_vol_usage.pl - Nagios Plugin - Check NetApp 7-Mode Volume Space Usage

=head1 SYNOPSIS

check_7mode_aggr_usage.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD --warning WARNING --critical CRITICAL --volume VOLUME

=head1 DESCRIPTION

Checks volume space usage for specified volume

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp 7-Mode filer to collect the data

=item --username USERNAME

The Login Username of the monitoring-User

=item --password PASSWORD

The Login Password of the monitoring-User

=item --warning WARNING

The Warning Threshold for Aggregate Usage

=item --critical CRITICAL

The Critical Threshold for Aggregate Usage

=item --volume VOLUME

The volume to check

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 if timeout occured
2 if the volume is fuller than CRITICAL
1 if the volume is fuller than WARNING
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>


