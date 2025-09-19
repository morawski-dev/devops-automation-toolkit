#!/bin/bash
TABLE_COUNT=`mysql -h localhost -u root -p${MARIADB_ROOT_PASSWORD} ${MARIADB_DATABASE} -e "select count(*) from information_schema.tables where table_schema='${MARIADB_DATABASE}';\G" | grep -v "count"`
if [ $TABLE_COUNT -gt 0 ]; then
   echo "$(date '+%Y-%m-%d %H:%M:%S') Database already restored skipping restore ..."
   exit 0
fi
if [[ ! -z "$AWS_ACCESS_KEY_ID" ]] && [[ ! -z "$AWS_SECRET_ACCESS_KEY" ]] && [[ ! -z "$AWS_DEFAULT_REGION" ]] && [[ ! -z "$AWS_S3_FILE_PATH" ]]; then
    rm -rf /tmp/aws_tmp
    mkdir -p "/tmp/aws_tmp"
    echo "$(date '+%Y-%m-%d %H:%M:%S') Download buckup from aws ..."
    BACKUP_FILE_NAME="$(aws s3 ls $AWS_S3_FILE_PATH | sort | grep "${MARIADB_DATABASE}" | tail -n 1 | awk '{print $4}')"
       echo "$(date '+%Y-%m-%d %H:%M:%S') Download buckup from aws $BACKUP_FILE_NAME"
    aws s3 cp "$AWS_S3_FILE_PATH$BACKUP_FILE_NAME" /tmp/aws_tmp/ --region $AWS_DEFAULT_REGION
    echo "$(date '+%Y-%m-%d %H:%M:%S') Unpacking files from aws ..."
    gunzip /tmp/aws_tmp/*.sql.gz
    echo "$(date '+%Y-%m-%d %H:%M:%S') Restoring buckup to local db ..."
    find /tmp/aws_tmp/ -type f -name "*.sql" -exec ln -s {} /tmp/aws_tmp/dump.sql \;
    mysql -h localhost -u root -p${MARIADB_ROOT_PASSWORD} ${MARIADB_DATABASE} < /tmp/aws_tmp/dump.sql
else
   echo "$(date '+%Y-%m-%d %H:%M:%S') Backup from AWS cannot be restored, set environment variables to restore aws database backup to docker one"
fi
