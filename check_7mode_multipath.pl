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

my @prim_paths;
my @sec_paths;
my @broken_disk_paths;
my @file;

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

walk_all_children($output);

my $filename = "/etc/config/lists/netapp_multipath/" . $Hostname;

if (-e "$filename"){
  open(FH, "$filename");
  @file = <FH>;
  close(FH);
}

my $index = 0;

foreach my $disk (@prim_paths){

  my $prim_path = 0;
  my $sec_path = 0;

  if($disk ne "none"){ $prim_path = 1; }
  if($sec_paths[$index] ne "none"){ $sec_path = 1; }

  if($prim_path != "1"){
    unless(grep( /$sec_paths[$index]/, @file )){
      push @broken_disk_paths, $sec_paths[$index];
    }
  }

  if($sec_path != "1"){
    unless(grep( /$disk/, @file )){
      push @broken_disk_paths, $disk;
    }
  }

  $index++;

}

if(@broken_disk_paths){
  print "Not All Disk Multipath: ";
  foreach (@broken_disk_paths) {
    print $_ . " ";
  }
  exit 2;
} else {
  print "OK - All Disk Multipath\n";
  exit 0;
}

sub walk_all_children {
  my $obj = shift;

  if ($obj->children_get) {
    walk_all_children($_) for $obj->children_get;
  }
  else {
    if ($obj->{name} eq "name"){
      unless($obj->{content}){
        push @prim_paths, "none";
      } else {
        push @prim_paths, $obj->{content};
      }
    }

                if ($obj->{name} eq "secondary-name"){
                        unless($obj->{content}){
                                push @sec_paths, "none";
                        } else {
                                push @sec_paths, $obj->{content};
                        }
                }

  }
}
