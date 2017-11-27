#!/usr/bin/perl

# --
# check_7mode_interfaces.pl - Check 7-Mode Interface Groups Status
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
    print "$0: ".$_[0]."\n";
    exit 2;
}
Error( 'Option --hostname needed!' ) unless $Hostname;
Error( 'Option --username needed!' ) unless $Username;
Error( 'Option --password needed!' ) unless $Password;

my $s = NaServer->new( $Hostname, 1, 3 );
$s->set_transport_type( "HTTPS" );
$s->set_style( "LOGIN" );
$s->set_admin_user( $Username, $Password );

my $lif_output = $s->invoke( 'net-config-get-active' );

if(ref ($lif_output) eq "NaElement" && $lif_output->results_errno != 0){
    $s->set_transport_type( "HTTP" );
    $lif_output = $s->invoke( "net-config-get-active" );
}

if ($lif_output->results_errno != 0) {
    my $r = $lif_output->results_reason();
    print "UNKNOWN: $r\n";
    exit 3;
}

my $net_config_info = $lif_output->child_get( "net-config-info" );
my $ifgrp_list = $net_config_info->child_get( "ifgrps" );

my @ifgrps = $ifgrp_list->children_get();

my %ifgrp_links = ();
my @ifgrp_interfaces;
my @failed_interfaces;

foreach my $ifgrp (@ifgrps) {

    my $ifgrp_name = $ifgrp->child_get_string( "interface-name" );

    my $link_list = $ifgrp->child_get( "links" );

    if ($link_list) {

        my @links = $link_list->children_get();

        foreach my $link (@links) {
            my $link_name = $link->get_content();
            unless (($link_name =~ /^lvif/) || ($link_name =~ /^svif/)) {
                push( @{$ifgrp_links{$ifgrp_name}}, $link_name );
                push( @ifgrp_interfaces, $link_name );
            }
        }
    }
}

my $interface_list = $net_config_info->child_get( "interfaces" );
my @interfaces = $interface_list->children_get();

foreach my $int (@interfaces) {

    my $name = $int->child_get_string( "interface-name" );
    my $state = $int->child_get_string( "mediatype" );

    if (grep(/$name/, @ifgrp_interfaces)) {
        my $state = $int->child_get_string( "mediatype" );

        unless ($state =~ /-up$/) {
            push( @failed_interfaces, $name );
        }
    }
}

my $failed_count = @failed_interfaces;

if ($failed_count != 0) {
    print "CRITICAL: ";
    foreach (@failed_interfaces) {
        print "$_ down, ";
    }
    print "\n";
    exit 2;
} else {
    print "OK: all ifgrps fully active\n";
    exit 0;
}

__END__

=encoding utf8

=head1 NAME

check_7mode_interfaces - Check 7-Mode Interface Group Status

=head1 SYNOPSIS

check_7mode_interfaces.pl --hostname HOSTNAME --username USERNAME \
           --password PASSWORD

=head1 DESCRIPTION

Checks if all Interface Groups have every single link up

=head1 OPTIONS

=over 4

=item --hostname FQDN

The Hostname of the NetApp to monitor

=item --username USERNAME

The Login Username of the NetApp to monitor

=item --password PASSWORD

The Login Password of the NetApp to monitor

=item -help

=item -?

to see this Documentation

=back

=head1 EXIT CODE

3 on Unknown Error
2 if any link is down
0 if everything is ok

=head1 AUTHORS

 Alexander Krogloth <git at krogloth.de>
