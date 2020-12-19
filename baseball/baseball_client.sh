#!/bin/sh

sleep 30

DB_CHECK=`mysqlshow -h baseball_db -u root baseball| grep -v Wildcard | grep -o baseball`
DB_NAME='baseball'

if [ "$DB_CHECK" == "$DB_NAME" ]; then
	mysql -h baseball_db -u root baseball < /scripts/boxscore_2.sql
else 
	mysql -h baseball_db -u root -e "create database baseball;"
	mysql -h baseball_db -u root -D baseball < baseball.sql
	mysql -h baseball_db -u root baseball < /scripts/boxscore_2.sql
fi

mkdir -p results/pre-analysis
mkdir -p results/pca_models
mkdir -p results/non-pca_models
mkdir -p results/non-pca_models_timesplit

python3 brute_force.py
python3 pca_models.py
python3 non-pca_models.py
python3 non-pca_models_time.py