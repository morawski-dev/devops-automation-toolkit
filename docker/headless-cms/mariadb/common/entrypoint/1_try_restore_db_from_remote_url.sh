#!/bin/bash
TABLE_COUNT=`mysql -h localhost -u root -p${MARIADB_ROOT_PASSWORD} ${MARIADB_DATABASE} -e "select count(*) from information_schema.tables where table_schema='${MARIADB_DATABASE}';\G" | grep -v "count"`
if [ $TABLE_COUNT -gt 0 ]; then
   echo "$(date '+%Y-%m-%d %H:%M:%S') Database already restored skipping restore ..."
   exit 0
fi
if [[ ! -z "${REMOTE_DB_DUMP_URL}" ]]; then
  CURRENT_DIR=$(pwd)
  echo "$(date '+%Y-%m-%d %H:%M:%S') Restoring database from external url ...."
  rm -rf /tmp/db_dump
  mkdir -p "/tmp/db_dump"
  cd /tmp/db_dump
  wget -O dump.zip "${REMOTE_DB_DUMP_URL}"
  echo "$(date '+%Y-%m-%d %H:%M:%S') Unpacking files ..."
  unzip *.zip
  echo "$(date '+%Y-%m-%d %H:%M:%S') Restoring buckup to local db ..."
  find . -type f -name "*.sql" -exec ln -s {} /tmp/db_dump/dump.sql \;
  mysql -h localhost -u root -p${MARIADB_ROOT_PASSWORD} ${MARIADB_DATABASE} < dump.sql
  rm -rf /tmp/db_dump/
  cd $CURRENT_DIR
  echo "$(date '+%Y-%m-%d %H:%M:%S') Restoring database from external url finished"
else
   echo "$(date '+%Y-%m-%d %H:%M:%S') Backup from url cannot be restored, set environment variables to restore backup from url to docker one"
fi