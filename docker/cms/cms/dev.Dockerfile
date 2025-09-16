FROM maven:3.8.8-eclipse-temurin-21-alpine as builder

ENV MAVEN_USER_HOME=/tmp/cms/.mvn
ENV MAVEN_CONFIG=""

COPY ./ /tmp/cms
WORKDIR /tmp/cms

RUN sed -i 's/\r//' ./mvnw
RUN chmod u+x mvnw
RUN ./mvnw clean install -DskipTests
RUN mkdir docker-deploy
RUN find docker/deploy -type f -name '*.jar' -exec echo {} \; -exec cp {} docker-deploy/ \;
RUN ls -al docker-deploy;


FROM liferay/portal:7.4.3.132-ga132-d8.0.0-20250218185242 as runner

LABEL vendor="XYZ"
LABEL maintainer="XYZ"
LABEL project="XYZ"
LABEL version="1.0"
LABEL image="cms"

# Liferay/Tomcat basics
ENV LANG=en_GB.UTF-8 LANGUAGE=en_GB:en
ENV LIFERAY_JVM_OPTS=
ENV LIFERAY_HOME=/opt/liferay
ENV JPDA_ADDRESS=8000
ENV LIFERAY_JPDA_ENABLED=false
#Set this to true to automatically upgrade the database when a module's build number has been increased since the last deployment.
ENV LIFERAY_UPGRADE_PERIOD_DATABASE_PERIOD_AUTO_PERIOD_RUN=true
# Set this property to true if the Setup Wizard should be displayed the first time the portal is started
ENV LIFERAY_SETUP_PERIOD_WIZARD_PERIOD_ENABLED=false
# Set this property to true to automatically add sample data to a new database on startup
ENV LIFERAY_SETUP_PERIOD_WIZARD_PERIOD_ADD_PERIOD_SAMPLE_PERIOD_DATA=false
# This sets the default web ID
ENV LIFERAY_COMPANY_PERIOD_DEFAULT_PERIOD_WEB_PERIOD_ID=liferay.com
# Company name
ENV LIFERAY_COMPANY_PERIOD_DEFAULT_PERIOD_NAME=Portal
# Default home URL of the portal
ENV LIFERAY_COMPANY_PERIOD_DEFAULT_PERIOD_HOME_PERIOD_URL=/web/guest
# Default landing page
ENV LIFERAY_DEFAULT_PERIOD_LANDING_PERIOD_PAGE_PERIOD_PATH=/web/guest
# Default logout page
ENV LIFERAY_DEFAULT_PERIOD_LOGOUT_PERIOD_PAGE_PERIOD_PATH=/web/guest
# OSGi console
ENV LIFERAY_MODULE_PERIOD_FRAMEWORK_PERIOD_PROPERTIES_PERIOD_OSGI_PERIOD_CONSOLE=0.0.0.0:11311
# Default locale of the portal
ENV LIFERAY_COMPANY_PERIOD_DEFAULT_PERIOD_LOCALE=en_GB
# Default time zone of the portal
ENV LIFERAY_COMPANY_PERIOD_DEFAULT_PERIOD_TIME_PERIOD_ZONE=UTC
# Set this to true if all users are required to agree to the terms of use
ENV LIFERAY_TERMS_PERIOD_OF_PERIOD_USE_PERIOD_REQUIRED=false
# Set this to true to enable reminder queries that are used to help reset a user's password
ENV LIFERAY_USERS_PERIOD_REMINDER_PERIOD_QUERIES_PERIOD_ENABLED=false
ENV LIFERAY_USERS_PERIOD_REMINDER_PERIOD_QUERIES_PERIOD_CUSTOM_PERIOD_QUESTION_PERIOD_ENABLED=false
# Set this to true to allow strangers to create accounts and register themselves on the portal
ENV LIFERAY_COMPANY_PERIOD_SECURITY_PERIOD_STRANGERS=false
# Set this to true to allow users to autocomplete the reminder query form based on their previously entered values
ENV LIFERAY_COMPANY_PERIOD_SECURITY_PERIOD_PASSWORD_PERIOD_REMINDER_PERIOD_QUERY_PERIOD_FORM_PERIOD_AUTOCOMPLETE=false
# Set this to true to allow users to ask the portal to send them a password reset link
ENV LIFERAY_COMPANY_PERIOD_SECURITY_PERIOD_SEND_PERIOD_PASSWORD_PERIOD_RESET_PERIOD_LINK=true
# Configure email notification settings
ENV LIFERAY_ADMIN_PERIOD_EMAIL_PERIOD_FROM_PERIOD_ADDRESS=portal@xyz.com
ENV LIFERAY_ADMIN_PERIOD_EMAIL_PERIOD_FROM_PERIOD_NAME=Portal
 # Set whether or not punlic layouts are enabled
ENV LIFERAY_LAYOUT_PERIOD_USER_PERIOD_PUBLIC_PERIOD_LAYOUTS_PERIOD_AUTO_PERIOD_CREATE=false
ENV LIFERAY_LAYOUT_PERIOD_USER_PERIOD_PUBLIC_PERIOD_LAYOUTS_PERIOD_ENABLED=false
# Set whether or not private layouts are enabled
ENV LIFERAY_LAYOUT_PERIOD_USER_PERIOD_PRIVATE_PERIOD_LAYOUTS_PERIOD_AUTO_PERIOD_CREATE=false
ENV LIFERAY_LAYOUT_PERIOD_USER_PERIOD_PRIVATE_PERIOD_LAYOUTS_PERIOD_ENABLED=false
# You can configure individual JSP pages to use a specific implementation of the available WYSIWYG editors
ENV LIFERAY_EDITOR_PERIOD_WYSIWYG_PERIOD_DEFAULT=ckeditor
ENV LIFERAY_EDITOR_PERIOD_WYSIWYG_PERIOD_PORTAL_MINUS_IMPL_PERIOD_PORTLET_PERIOD_DDM_PERIOD_TEXT_UNDERLINE_HTML_PERIOD_FTL=ckeditor
# The login field is prepopulated with the company's domain name if the login is unpopulated and user authentication is based on email addresses
ENV LIFERAY_COMPANY_PERIOD_LOGIN_PERIOD_PREPOPULATE_PERIOD_DOMAIN=false
# The portal can authenticate users based on their email address, screen name, or user ID
ENV LIFERAY_COMPANY_PERIOD_SECURITY_PERIOD_AUTH_PERIOD_TYPE=emailAddress
# Set this to the appropriate encryption algorithm to be used for company level encryption algorithms
ENV LIFERAY_COMPANY_PERIOD_ENCRYPTION_PERIOD_ALGORITHM=AES
# Set this to define the size used for the company wide encryption key
ENV LIFERAY_COMPANY_PERIOD_ENCRYPTION_PERIOD_KEY_PERIOD_SIZE=128
# Set this to true to enable administrators to impersonate other users
ENV LIFERAY_PORTAL_PERIOD_IMPERSONATION_PERIOD_ENABLE=true
# Set the following encryption algorithm to encrypt passwords
ENV LIFERAY_PASSWORDS_PERIOD_ENCRYPTION_PERIOD_ALGORITHM=PBKDF2WithHmacSHA1/160/128000

### OPTIMIZATION ###
# If the user can unzip compressed HTTP content, the GZip filter will zip up the HTTP content before sending it to the user. This will speed up page rendering for users that are on dial up
ENV LIFERAY_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SERVLET_PERIOD_FILTERS_PERIOD_GZIP_PERIOD__UPPERCASEG__UPPERCASEZ_IP_UPPERCASEF_ILTER=false
# Set this to true to track user clicks in memory for the duration of a user's session. Setting this to true allows you to view all live sessions in the Admin portlet
ENV LIFERAY_SESSION_PERIOD_TRACKER_PERIOD_MEMORY_PERIOD_ENABLED=false
# Set this to true to enable pingback
ENV LIFERAY_BLOGS_PERIOD_PINGBACK_PERIOD_ENABLED=false
# Set this to true to enable trackbacks
ENV LIFERAY_BLOGS_PERIOD_TRACKBACK_PERIOD_ENABLED=false
# Set this to true to enable tracking via Live Users
ENV LIFERAY_LIVE_PERIOD_USERS_PERIOD_ENABLED=false
# Set this to true to enable pingbacks
ENV LIFERAY_MESSAGE_PERIOD_BOARDS_PERIOD_RATINGS_PERIOD_ENABLED=false
# Set this to true to enable pinging Google on new and updated blog entries
ENV LIFERAY_BLOGS_PERIOD_PING_PERIOD_GOOGLE_PERIOD_ENABLED=false
# Enter time in days to automatically expire bans on users. Set this property or the property "message.boards.expire.ban.job.interval" to 0 to disable auto expire
ENV LIFERAY_MESSAGE_PERIOD_BOARDS_PERIOD_EXPIRE_PERIOD_BAN_PERIOD_INTERVAL=0
# The Sharepoint filter allows users to access documents in the Document Library directly from Microsoft Office using the Sharepoint protocol
ENV LIFERAY_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SHAREPOINT_PERIOD__UPPERCASES_HAREPOINT_UPPERCASEF_ILTER=false
# The strip filter will remove blank lines from the outputted content. This will significantly speed up page rendering
ENV LIFERAY_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SERVLET_PERIOD_FILTERS_PERIOD_STRIP_PERIOD__UPPERCASES_TRIP_UPPERCASEF_ILTER=false
# The header filter is used to set request headers
ENV LIFERAY_COM_PERIOD_LIFERAY_PERIOD_PORTAL_PERIOD_SERVLET_PERIOD_FILTERS_PERIOD_HEADER_PERIOD__UPPERCASEH_EADER_UPPERCASEF_ILTER=false
# Set the number of increments between database updates to the Counter table. Set this value to a higher number for better performance
ENV LIFERAY_COUNTER_PERIOD_INCREMENT=2000
# Set this property to true to load the theme's merged CSS files for faster loading for production
ENV LIFERAY_THEME_PERIOD_CSS_PERIOD_FAST_PERIOD_LOAD=true
# Set this property to true to load the theme's merged image files for faster loading for production
ENV LIFERAY_THEME_PERIOD_IMAGES_PERIOD_FAST_PERIOD_LOAD=true
# Set this property to true to load the packed version of files
ENV LIFERAY_JAVASCRIPT_PERIOD_FAST_PERIOD_LOAD=true
# Configure path to jgroups control chanel
ENV LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_CONTROL=/opt/liferay/tomcat/webapps/ROOT/WEB-INF/classes/tcp_control.xml
# Configure path to jgroups transport chanel
ENV LIFERAY_CLUSTER_PERIOD_LINK_PERIOD_CHANNEL_PERIOD_PROPERTIES_PERIOD_TRANSPORT_PERIOD_0=/opt/liferay/tomcat/webapps/ROOT/WEB-INF/classes/tcp_transport.xml
# Specify the number of minutes before a session expires. This value is always overridden by the value set in web.xml
ENV LIFERAY_SESSION_PERIOD_TIMEOUT=30
# Specify the number of minutes before a warning is sent to the user informing the user of the session expiration
ENV LIFERAY_SESSION_PERIOD_TIMEOUT_PERIOD_WARNING=1
# Set the auto-extend mode to true to avoid having to ask the user whether to extend the session or not
ENV LIFERAY_SESSION_PERIOD_TIMEOUT_PERIOD_AUTO_PERIOD_EXTEND=true
# Redirect to default page after session timeout
ENV LIFERAY_SESSION_PERIOD_TIMEOUT_PERIOD_REDIRECT_PERIOD_ON_PERIOD_EXPIRE=true
# Setup hikari max lifetime shorten then wait_timeout on db which is currently set to 600s
ENV LIFERAY_JDBC_PERIOD_DEFAULT_PERIOD_MAX_UPPERCASEL_IFETIME=570000
# Configure prometheus exporter
ENV CATALINA_OPTS="$CATALINA_OPTS -javaagent:/opt/liferay/tomcat/lib/jmx_prometheus_javaagent-0.17.2.jar=7171:/opt/liferay/tomcat/conf/prometheus_exporter_tomcat.yml"

# These are the publicly exposed ports
EXPOSE 8000 8009 8080 11311

USER root

RUN apt-get update && apt-get install -y perl && apt-get install -y netcat-traditional && apt-get install -y wget && apt-get install -y xmlstarlet && rm -rf /var/lib/apt

RUN wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.17.2/jmx_prometheus_javaagent-0.17.2.jar  \
    -P /opt/liferay/tomcat/lib  \
    && chown liferay:liferay /opt/liferay/tomcat/lib/jmx_prometheus_javaagent-0.17.2.jar

COPY docker/jvm/zulu11/conf/security/java.security /usr/lib/jvm/zulu11/conf/security/java.security
COPY --chown=liferay:liferay --from=builder /tmp/cms/docker/entrypoint.sh /entrypoint.sh
COPY --chown=liferay:liferay --from=builder /tmp/cms/docker/tomcat/ /opt/liferay/tomcat/
COPY --chown=liferay:liferay --from=builder /tmp/cms/configs/common/ /opt/liferay/osgi/configs/

COPY --chown=liferay:liferay --from=builder /tmp/cms/docker-deploy/ /opt/liferay/deploy/

RUN chown -R liferay /opt/liferay

# This health check is the same used with DXPC, increase timeout to avoid restart container on upgrade
# https://github.com/lgdd/liferay-healthcheck#compatibility
HEALTHCHECK \
	--interval=30s \
	--start-period=10m \
	--timeout=60m \
	CMD curl -H "X-Request-ID: INTERNAL_HEALTH_CHECK" -H "X-Correlation-ID: INTERNAL_HEALTH_CHECK" \
	 -fsS "http://localhost:8080/o/health/readiness" || exit 1

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

USER liferay
