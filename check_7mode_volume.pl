#!/usr/bin/perl

# --
# check_7mode_volume.pl - Check NetApp System Volume Usage
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
	'size-warning=i' => \my $Size_Warning,
	'size-critical=i' => \my $Size_Critical,	
    'inode-warning=i' => \my $Inode_Warning,
    'inode-critical=i' => \my $Inode_Critical,
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
Error('Option --size-warning needed!') unless $Size_Warning;
Error('Option ---size-critical needed!') unless $Size_Critical;
Error('Option --inode-warning needed!') unless $Inode_Warning;
Error('Option ---inode-critical needed!') unless $Inode_Critical;

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

    my $state = $vol->child_get_string("state");

    if($state eq "restricted"){
        print "WARNING: Volume '$Volume' restricted";
        exit 1;
    } elsif ($state eq "offline"){
        print "WARNING: Volume '$Volume' offline";
        exit 1;
    } else {
        my $inode_used = $vol->child_get_int("files-used");
        my $inode_total = $vol->child_get_int("files-total");
        my $inode_percent = sprintf("%.2f", $inode_used/$inode_total*100);

        my $used = $vol->child_get_int("percentage-used");

        if(($used>=$Size_Critical) || ($inode_percent>=$Inode_Critical)){
            print "CRITICAL: $Volume (Size: $used%, Inodes: $inode_percent%)\n";              
            exit 2;
        } elsif (($used>=$Size_Warning) || ($inode_percent>=$Inode_Warning)){
            print "WARNING: $Volume (Size: $used%, Inodes: $inode_percent%)\n";
            exit 1;
        } else {
            print "OK: $Volume (Size: $used%, Inodes: $inode_percent%)\n";
            exit 0;
        }
    }
}


__END__

=encoding utf8

=head1 NAME

check_7mode_vol_usage.pl - Nagios Plugin - Check NetApp 7-Mode Volume Usage

=head1 SYNOPSIS

check_7mode_aggr_usage.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD --size-warning WARNING --size-critical CRITICAL --volume VOLUME \
           --inode-warning WARNING --inode-critical WARNING

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

=item --size-warning WARNING

The Warning Threshold for Volume Space Usage

=item --size-critical CRITICAL

The Critical Threshold for Volume Space Usage

=item --inode-warning WARNING

The Warning Threshold for Volume Inode Usage

=item --inode-critical CRITICAL

The Critical Threshold for Volume Inode Usage

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
 Stephan Lang <stephan.lang at acp.at>

