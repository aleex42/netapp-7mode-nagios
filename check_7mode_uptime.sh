#!/bin/bash

# --
# check_7mode_uptime.sh Check NetApp System Uptime
# Copyright (C) 2013 noris network AG, http://www.noris.net/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (GPL). If you
# did not receive this file, see http://www.gnu.org/licenses/gpl.txt.
# --
 
HOST=$1
COMMUNITY=$2
MUST_UPTIME=$3
 
UPTIME=$(/usr/bin/snmpwalk -v 2c -c $COMMUNITY $HOST .1.3.6.1.2.1.1.3.0 | awk -F \( '{ print $2 }' | awk -F \) '{ print $1 }')
 
UPTIME_MINUTES=$(echo $UPTIME/6000 | bc)
ROUNDED_DAYS=$(echo "scale=2; $UPTIME_MINUTES/1440" | bc -l)
 
if [ $UPTIME_MINUTES -lt $MUST_UPTIME ]; then
        echo "CRITICAL - Uptime only $UPTIME_MINUTES minutes"
        exit 2
else
        echo "OK - Uptime $UPTIME_MINUTES minutes (~ $ROUNDED_DAYS days)"
        exit 0
fi
