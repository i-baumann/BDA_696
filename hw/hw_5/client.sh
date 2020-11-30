#!/bin/sh

sleep 10

DB_CHECK=`mysqlshow -h mysql_db -u root baseball| grep -v Wildcard | grep -o baseball`
DB_NAME='baseball'

if [ "$DB_CHECK" == "$DB_NAME" ]; then
	mysql -h mysql_db -u root baseball < /scripts/running_avg.sql
else 
	mysql -h mysql_db -u root -e "create database baseball;"
	mysql -h mysql_db -u root -D baseball < /data/baseball.sql
	mysql -h mysql_db -u root baseball < /scripts/running_avg.sql
fi

mysql -h mysql_db -u root baseball -e '
  SELECT * FROM rolling_avg_day_faster ;' > /results/rolling_avg.txt

mysql -h mysql_db -u root baseball -e '
  SELECT * FROM rolling_avg_day_faster
  WHERE game_id = 12560 ;' > /results/rolling_avg_12560.txt
