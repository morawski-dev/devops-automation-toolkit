#!/bin/bash
TABLE_COUNT=`mysql -h localhost -u root -p${MARIADB_ROOT_PASSWORD} ${MARIADB_DATABASE} -e "select count(*) from information_schema.tables where table_schema='${MARIADB_DATABASE}';\G" | grep -v "count"`
if [ $TABLE_COUNT -gt 0 ]; then
   echo "$(date '+%Y-%m-%d %H:%M:%S') Database already restored skipping remote db restore ..."
   exit 0
fi
if [[ ! -z "$REMOTE_DB_HOST" ]] && [[ ! -z "$REMOTE_DB_USERNAME" ]] && [[ ! -z "$REMOTE_DB_PASSWORD" ]] && [[ ! -z "$REMOTE_DB_NAME" ]]; then
    echo "$(date '+%Y-%m-%d %H:%M:%S') Downloading buckup from remote server ..."
    mysqldump -h ${REMOTE_DB_HOST} -p${REMOTE_DB_PASSWORD} -u ${REMOTE_DB_USERNAME}  ${REMOTE_DB_NAME} > /tmp/dump.sql
    echo "$(date '+%Y-%m-%d %H:%M:%S') Restoring buckup to local db ..."
    mysql -h localhost -u root -p${MARIADB_ROOT_PASSWORD} ${MARIADB_DATABASE} < /tmp/dump.sql
    rm -rf /tmp/dump.sql
    echo "$(date '+%Y-%m-%d %H:%M:%S') Restoring buckup to local db end :)"
else
    echo "$(date '+%Y-%m-%d %H:%M:%S') Backup from remote host cannot be restored, set environment variables to restore remote database to docker one"
fi
