#!/usr/bin/perl

# check_7mode_disk
# usage: ./check_7mode_disk hostname username password
# Alexander Krogloth <git at krogloth.de>

use lib "/usr/lib/netapp-manageability-sdk-5.1/lib/perl/NetApp";
use NaServer;
use NaElement;
use strict;
use warnings;

my $s = NaServer->new ($ARGV[0], 1, 3);

$s->set_transport_type("HTTPS");
$s->set_style("LOGIN");
$s->set_admin_user($ARGV[1], $ARGV[2]);
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
