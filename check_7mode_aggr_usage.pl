#!/usr/bin/perl

# --
# check_7mode_aggr_usage.pl - Check NetApp System Aggregate Space Usage (default: allocated blocks including thick provisioned volumes)
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
    'warning=i'  => \my $Warning,
    'critical=i' => \my $Critical,
    'real=s'     => \my $real,
    'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error( "$0: Error in command line arguments\n" );

sub Error {
    print "$0: ".shift;
    exit 2;
}
Error( 'Option --hostname needed!' ) unless $Hostname;
Error( 'Option --username needed!' ) unless $Username;
Error( 'Option --password needed!' ) unless $Password;
Error( 'Option --warning needed!' ) unless $Warning;
Error( 'Option --critical needed!' ) unless $Critical;

my $s = NaServer->new ( $Hostname, 1, 3 );

$s->set_transport_type( "HTTPS" );
$s->set_style( "LOGIN" );
$s->set_admin_user( $Username, $Password );
$s->set_timeout( 60 );

my $output = $s->invoke( "aggr-space-list-info" );

if(ref ($output) eq "NaElement" && $output->results_errno != 0){
    $s->set_transport_type( "HTTP" );
    $output = $s->invoke( "aggr-space-list-info" );
}

if ($output->results_errno != 0) {
    my $r = $output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $aggrs = $output->child_get( "aggregates" );
my @result = $aggrs->children_get();

my $warning_aggrs = 0;
my $critical_aggrs = 0;
my $message;

foreach my $aggr (@result) {

    my ($aggr_alloc, $aggr_used, $size);

    my $aggr_name = $aggr->child_get_string( "aggregate-name" );
    my $aggr_free = $aggr->child_get_string( "size-free" );

    if ($real) {
        $aggr_alloc = $aggr->child_get_int( "size-volume-allocated" );
        $aggr_used = $aggr->child_get_string( "size-volume-used" );
        $size = $aggr_alloc + $aggr_free;
    } else {
        $aggr_alloc = $aggr->child_get_int( "size-allocated" );
        $aggr_used = $aggr->child_get_string( "size-used" );
        $size = $aggr_used + $aggr_free;
    }

    my $percent = $aggr_used / $size * 100;
    my $percent_rounded = sprintf( "%.2f", $percent );

    if ($percent >= $Critical) {
        $critical_aggrs++;
    } elsif ($percent >= $Warning) {
        $warning_aggrs++;
    }

    if ($message) {
        $message .= ", ".$aggr_name." (".$percent_rounded."%)";
    } else {
        $message .= $aggr_name." (".$percent_rounded."%)";
    }
}

if ($critical_aggrs > 0) {
    print "CRITICAL: ".$message."\n";
    exit 2;
} elsif ($warning_aggrs > 0) {
    print "WARNING: ".$message."\n";
    exit 1;
} else {
    print "OK: ".$message."\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_7mode_aggr_usage.pl - Nagios Plugin - Check NetApp 7-Mode Aggregate Space Usage

=head1 SYNOPSIS

check_7mode_aggr_usage.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD --warning WARNING --critical CRITICAL [--real true]

=head1 DESCRIPTION

Checks aggregate real allocated space usage for all filer's aggregates

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

=item --real true

Check the real used space if specified

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 if timeout occured
2 if any aggregate is fuller than CRITICAL
1 if any aggregate is fuller than WARNING
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>


