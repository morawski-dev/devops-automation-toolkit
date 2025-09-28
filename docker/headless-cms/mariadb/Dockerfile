FROM mariadb:10.6.17

LABEL vendor="XYZ"
LABEL maintainer="XYZ"
LABEL project="XYZ"
LABEL version="1.0"
LABEL image="mariadb"

RUN apt-get update && \
    apt-get install -y netcat && \
    apt-get install -y unzip wget && \
    apt-get install -y python3 && \
    apt-get install -y python3-pip python3-dev build-essential && \
    pip install awscli && \
    rm -rf /var/lib/apt

RUN adduser -u 1500 --disabled-password --gecos "" --home /var/lib/mysql --no-create-home docker_noroot
RUN chown -R docker_noroot /var/lib/mysql

COPY common/my.cnf /etc/mysql/my.cnf
RUN chmod 644 /etc/mysql/my.cnf

COPY common/entrypoint/1_try_restore_db_from_remote_url.sh /docker-entrypoint-initdb.d/1_try_restore_db_from_remote_url.sh
RUN chmod +x /docker-entrypoint-initdb.d/1_try_restore_db_from_remote_url.sh

COPY common/entrypoint/2_try_restore_db_from_aws_bucket.sh /docker-entrypoint-initdb.d/2_try_restore_db_from_aws_bucket.sh
RUN chmod +x /docker-entrypoint-initdb.d/2_try_restore_db_from_aws_bucket.sh

COPY common/entrypoint/3_try_restore_db_from_remote_db.sh /docker-entrypoint-initdb.d/3_try_restore_db_from_remote_db.sh
RUN chmod +x /docker-entrypoint-initdb.d/3_try_restore_db_from_remote_db.sh

EXPOSE 3306

USER docker_noroot

CMD ["mariadbd"]
