#!/bin/sh

mysql -h 172.19.0.2 -P 3307 baseball < baseball.sql
#mysql < /scripts/running_avg.sql
#echo "This is a test (2)"

if [ -d /var/lib/mysql/baseball ] ; then 
    # Do Stuff ...
fi
