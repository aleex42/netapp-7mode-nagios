#!/usr/bin/perl

# --
# check_7mode_snapshot_state.pl - Check Snapshots State
# Copyright (C) 2017 Giorgio Maggiolo, http://www.maggiolo.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --

use strict;

use common::sense;
use NaServer;
use NaElement;
use Getopt::Long;

GetOptions (
	'hostname=s' => \my $hostname,
	'username=s' => \my $username,
	'password=s' => \my $password,
	'volume=s' => \my $snapshot_name;
	'help|?'     => sub { exec perldoc => -F => $0 or die "Cannot execute perldoc: $!\n"; },
) or Error( "$0: Error in command line arguments\n" );

sub Error {
    print "$0: ".shift;
    exit 2;
}

Error( 'Option --hostname needed!' ) unless $Hostname;
Error( 'Option --username needed!' ) unless $Username;
Error( 'Option --password needed!' ) unless $Password;
