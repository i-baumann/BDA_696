#!/usr/bin/env bash

# Download jar file to ensure correct driver
wget --quiet -c https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-8.0.21.tar.gz -O - | tar -zxvf - mysql-connector-java-8.0.21/mysql-connector-java-8.0.21.jar --strip-components=1

# Would not work with -C option, so jankily moving to jar folder in pyspark
mv mysql-connector-java-8.0.21.jar ../venv/lib/python3.8/site-packages/pyspark/jars/

source ../venv/bin/activate

pip install -r ../requirements.txt

python3 hw3.py