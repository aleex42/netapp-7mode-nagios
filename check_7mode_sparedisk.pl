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

my $s = NaServer->new ( $Hostname, 1, 3 );

$s->set_transport_type( "HTTPS" );
$s->set_style( "LOGIN" );
$s->set_admin_user( $Username, $Password );
$s->set_timeout( 60 );

my $output = $s->invoke( "disk-list-info" );

if ($output->results_errno != 0) {
    my $r = $output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $unowned = 0;
my $normal = 0;
my $notzero = 0;

my $disks = $output->child_get( "disk-details" );
my @result = $disks->children_get();

foreach my $disk (@result) {

    my $disk_state = $disk->child_get_string( "raid-state" );

    if ($disk_state eq "spare") {

        my $zero_state = $disk->child_get_string( "is-zeroed" );

        if ($zero_state eq "false") {
            $notzero++;
        } else {
            $normal++;
        }
    }
}

my $owned_output = $s->invoke( "disk-sanown-list-info" );

if ($owned_output->results_errno != 0) {
    my $r = $owned_output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $owned = $owned_output->child_get( "disk-sanown-details" );
my @owned_result = $owned->children_get();

foreach my $owned_disk (@owned_result) {

    my $disk_name = $owned_disk->child_get_string( "name" );
    my $disk_owner = $owned_disk->child_get_string( "owner" );

    unless ($disk_owner) {
        $unowned++;
    }
}

if ($notzero > 0) {
    if ($unowned > 0) {
        print "CRITICAL: $unowned disks unowned - $notzero spares not zeroed\n";
        exit 2;
    } else {
        print "WARNING: $notzero spares not zeroed - $normal normal spares\n";
        exit 1;
    }
}
elsif ($unowned > 0) {
    print "CRITICAL: $unowned disks unowned\n";
    exit 2;
} else {
    print "OK: $normal normal spares \n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_7mode_sparedisk.pl - Nagios Plugin - Check NetApp 7-Mode Spare Disk 

=head1 SYNOPSIS

check_7mode_sparedisk.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD

=head1 DESCRIPTION

Checks if all spare disks are zeroed

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
1 if any spare disk is not zeroed
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>


