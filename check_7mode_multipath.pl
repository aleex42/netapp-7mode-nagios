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

use lib "/usr/lib/netapp-manageability-sdk/lib/perl/NetApp";
use NaServer;
use NaElement;
use Getopt::Long;

GetOptions(
    'hostname=s' => \my $Hostname,
    'username=s' => \my $Username,
    'password=s' => \my $Password,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error( "$0: Error in command line arguments\n" );

sub Error {
    print "$0: ".shift;
    exit 2;
}
Error( 'Option --hostname needed!' ) unless $Hostname;
Error( 'Option --username needed!' ) unless $Username;
Error( 'Option --password needed!' ) unless $Password;

my @prim_paths;
my @sec_paths;
my @broken_disk_paths;
my @file;

my $s = NaServer->new ( $Hostname, 1, 3 );
$s->set_server_type( "FILER" );
$s->set_transport_type("HTTPS");
#$s->set_port(443);
$s->set_style( "LOGIN" );
$s->set_admin_user( $Username, $Password );
#$s->set_timeout(60);

my $api = new NaElement( "disk-list-info" );
my $output = $s->invoke_elem( $api );

if(ref ($output) eq "NaElement" && $output->results_errno != 0){
    $s->set_transport_type( "HTTP" );
    $output = $s->invoke( "disk-list-info" );
}

if ($output->results_errno != 0) {
    my $r = $output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

walk_all_children( $output );

my $filename = "/etc/config/lists/netapp_multipath/".$Hostname;

if (-e "$filename") {
    open( FH, "$filename" );
    @file = <FH>;
    close( FH );
}

my $index = 0;

foreach my $disk (@prim_paths) {

    my $prim_path = 0;
    my $sec_path = 0;

    if ($disk ne "none") { $prim_path = 1; }
    if ($sec_paths[$index] ne "none") { $sec_path = 1; }

    if ($prim_path != "1") {
        unless (grep( /$sec_paths[$index]/, @file )) {
            push @broken_disk_paths, $sec_paths[$index];
        }
    }

    if ($sec_path != "1") {
        unless (grep( /$disk/, @file )) {
            push @broken_disk_paths, $disk;
        }
    }

    $index++;

}

if (@broken_disk_paths) {
    print "Not All Disk Multipath: ";
    foreach (@broken_disk_paths) {
        print $_." ";
    }
    exit 2;
} else {
    print "OK - All Disk Multipath\n";
    exit 0;
}

sub walk_all_children {
    my $obj = shift;
    if ($obj->children_get) {
        walk_all_children( $_ ) for $obj->children_get;
    } else {
        if ($obj->{name} eq "name") {
            unless ($obj->{content}) {
                push @prim_paths, "none";
            } else {
                push @prim_paths, $obj->{content};
            }
        }
        if ($obj->{name} eq "secondary-name") {
            unless ($obj->{content}) {
                push @sec_paths, "none";
            } else {
                push @sec_paths, $obj->{content};
            }
        }
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

3 if timeout occured
2 if any disk is not multipathed
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>

