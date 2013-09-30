#!/usr/bin/perl

# --
# check_7mode_multipath.pl - Check NetApp System Disk Multipath
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

my $s = NaServer->new ($Hostname, 1, 3);

$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user($Username, $Password);
$s->set_timeout(60);

my $output = $s->invoke("aggr-list-info");
my $aggrs = $output->child_get("aggregates");
my @result = $aggrs->children_get();

my %double_reconst_aggr = ();
my %reverse_double_reconst_aggr = ();

foreach my $aggr (@result){

    my $aggr_status = $aggr->child_get_string("raid-status");
    my $aggr_name = $aggr->child_get_string("name");
    my $disk_output = $s->invoke("disk-list-info");

    my $disks = $disk_output->child_get("disk-details");
    my @disk_result = $disks->children_get();
    my $reconstruct_count = 0;

    foreach my $disk (@disk_result){

        my $disk_aggr = $disk->child_get_string("aggregate");
        my $disk_name = $disk->child_get_string("name");
        my $raid_state = $disk->child_get_string("raid-state");

        if($raid_state ne "spare" && $disk_aggr eq $aggr_name && $raid_state eq "reconstructing"){
            $reconstruct_count++;
        }
    }
    $double_reconst_aggr{$aggr_name} = $reconstruct_count;
}

while (my ($k, $v) = each %double_reconst_aggr) {
    push @{ $reverse_double_reconst_aggr{$v} }, $k;
}

for my $key ( keys %reverse_double_reconst_aggr ) {
    my $value = $reverse_double_reconst_aggr{$key};
    my $aggrs = join ', ', @{ $reverse_double_reconst_aggr{$key} };

    if($reverse_double_reconst_aggr{2}){
        print "CRITICAL - double reconstruct on $aggrs\n";
        exit 2;
    } elsif($reverse_double_reconst_aggr{1}){
        print "WARNING - reconstruct on $aggrs\n";
        exit 1;
    } else {
        print "OK - no reconstruct\n";
        exit 0;
    }
}

__END__

=encoding utf8

=head1 NAME

check_7mode_multipath.pl - Nagios Plugin - Check NetApp 7-Mode Disk Multipath

=head1 SYNOPSIS

check_7mode_multipath.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD

=head1 DESCRIPTION

Checks multipathing for all NetApp Disks

It is also possible to specify some whitelists - for example you have an filer with internal SAS-disks.
These disks are typically not multipathed if you haven't got a HA-pair.

Just add these disks to your whitelist-file (/etc/config/lists/netapp_multipath/HOSTNAME) like this:

"0a.00.21 0a.00.17 0a.00.13 0a.00.6 0a.00.4 0a.00.2 0a.00.22 0a.00.18 0a.00.8 0a.00.16 0a.00.12 0a.00.11 0a.00.15 0a.00.0 0a.00.9 0a.00.1 0a.00.3 0a.00.19 0a.00.10 0a.00.5 0a.00.20 0a.00.14 0a.00.23 0a.00.7"

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

2 if any disk is not multipathed
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>

