#!/usr/bin/perl

# --
# check_7mode_sparedisk.pl - Check NetApp System Spare Disks State
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

my $output = $s->invoke("disk-list-info");

if ($output->results_errno != 0) {
  my $r = $output->results_reason();
  print "UNKNOWN - Timeout: $r\n";
  exit 3;
}

my $normal = 0;
my $notzero = 0;

my $disks = $output->child_get("disk-details");
my @result = $disks->children_get();

foreach my $disk (@result){

  my $disk_state = $disk->child_get_string("raid-state");

  if($disk_state eq "spare"){

    my $zero_state = $disk->child_get_string("is-zeroed");

    if($zero_state eq "false"){
      $notzero++;
    } else {
      $normal++;
    }
  }
}

if($notzero > 0){
        print "WARNING: $notzero spares not zeroed - $normal normal spares\n";
        exit 1;
} else {
        print "OK: $normal normal spares \n";
        exit 0;
}
