#!/usr/bin/perl

# --
# check_7mode_snapmirror.pl - Check NetApp System SnapMirror Age
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
    'lag=i'      => \my $LagOpt,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error( "$0: Error in command line arguments\n" );

sub Error {
    print "$0: ".shift;
    exit 2;
}
Error( 'Option --hostname needed!' ) unless $Hostname;
Error( 'Option --username needed!' ) unless $Username;
Error( 'Option --password needed!' ) unless $Password;
$LagOpt = 3600 * 28 unless $LagOpt; # 1 day 3 hours

my $old = 0;
my $old_snapmirrors;

my $s = NaServer->new ( $Hostname, 1, 3 );

$s->set_transport_type( "HTTPS" );
$s->set_style( "LOGIN" );
$s->set_admin_user( $Username, $Password );

my $snapmirror_output = $s->invoke( "snapmirror-get-status" );

if(ref ($snapmirror_output) eq "NaElement" && $snapmirror_output->results_errno != 0){
    $s->set_transport_type( "HTTP" );
    $snapmirror_output = $s->invoke( "snapmirror-get-status" );
}

if ($snapmirror_output->results_errno != 0) {
    my $r = $snapmirror_output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $snapmirror = $snapmirror_output->child_get( "snapmirror-status" );
if ($snapmirror) {

    my @snapmirror_result = $snapmirror->children_get();

    foreach my $sm (@snapmirror_result) {

        my $dest_name = $sm->child_get_string( "destination-location" );
        my $lag = $sm->child_get_int( "lag-time" );

        if ($lag >= $LagOpt) {
            $old++;
            if ($old_snapmirrors) {
                $old_snapmirrors .= ", $dest_name";
            } else {
                $old_snapmirrors = "$dest_name";
            }
        }
    }
}

if ($old ne "0") {
    print "$old old snapsmirror(s) older than 1 day:\n";
    print "$old_snapmirrors\n";
    exit 2;
} else {
    print "All SnapMirrors up2date\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_7mode_snapmirror.pl - Nagios Plugin - Check NetApp 7-Mode SnapMirror Age

=head1 SYNOPSIS

check_7mode_snapmirror.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD

=head1 DESCRIPTION

Checks if there are any snapmirrors older than 1 day

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp 7-Mode filer to collect the data

=item --username USERNAME

The Login Username of the monitoring-User

=item --password PASSWORD

The Login Password of the monitoring-User

=item --lag DELAY-SECONDS

Snapmirror delay in Seconds. Default 28h

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 if timeout occured
2 if there are any snapmirrors older than 1 day
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>


