#!/usr/bin/perl

# --
# check_7mode_ntp.pl - Check NetApp System NTP time
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
    'diff=i'     => \my $Diff,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error( "$0: Error in command line arguments\n" );

sub Error {
    print "$0: ".shift;
    exit 2;
}
Error( 'Option --hostname needed!' ) unless $Hostname;
Error( 'Option --username needed!' ) unless $Username;
Error( 'Option --password needed!' ) unless $Password;
Error( 'Option --diff needed!' ) unless $Diff;

my $s = NaServer->new ( $Hostname, 1, 3 );

$s->set_transport_type( "HTTPS" );
$s->set_style( "LOGIN" );
$s->set_admin_user( $Username, $Password );
$s->set_timeout( 60 );

my $output = $s->invoke( "clock-get-clock" );

if ($output->results_errno != 0) {
    my $r = $output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $time_netapp = $output->child_get_string( "local-time" );

my $time_now = time();

my $ntp_diff = $time_now - $time_netapp;

if ($ntp_diff >= $Diff) {
    print "NetApp time is $ntp_diff seconds different - check NTP";
    exit 2;
} else {
    print "NetApp time is OK";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_7mode_ntp.pl - Nagios Plugin - Check NetApp 7-Mode NTP time

=head1 SYNOPSIS

check_7mode_ntp.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD --diff DIFF

=head1 DESCRIPTION

Checks time NetApp System

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp 7-Mode filer to collect the data

=item --username USERNAME

The Login Username of the monitoring-User

=item --password PASSWORD

The Login Password of the monitoring-User

=item --diff DIFF

Time in seconds the NetApp System could be different before the check alarms.

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 if timeout occured
2 if NetApp time is more than DIFF seconds away from local system time
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>

