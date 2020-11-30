#!/usr/bin/env bash

# Database check
DB=baseball.sql
if test -f "$DB"; then
    echo "$DB exists, proceeding."
else
	echo "Please place $DB in directory!"
	exit
fi

# Results check
RESULT1=rolling_avg.csv
RESULT2=rolling_avg_12560.csv
if test -f "$RESULT1" | test -f "$RESULT2"; then
    rm $RESULT1 $RESULT2
fi

docker-compose -v down

# Build mysql container
docker-compose up -d --build mysql_db

# Create read/write permission for mysql user on volume dir,
# for some reason can't get to work with command in compose
docker exec -it mysql_db bash -c "chmod a+w /data/"

# Build client container
docker-compose up -d --build client
