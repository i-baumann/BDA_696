#!/usr/bin/env bash

DB=baseball.sql

if test -f "$DB"; then
	echo "$DB exists, proceeding."
else
  echo "$DB does not exist, downloading."
  curl -O https://teaching.mrsharky.com/data/baseball.sql.tar.gz
  tar -xvzf baseball.sql.tar.gz
fi

# Build db container
docker-compose up -d baseball_db

