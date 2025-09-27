FROM maildev/maildev:2.1.0 as base

FROM node:22-alpine3.19 as runner

USER node
WORKDIR /home/node

COPY --chown=node:node --from=base /home/node /home/node

EXPOSE 1080 1025
ENV MAILDEV_WEB_PORT 1080
ENV MAILDEV_SMTP_PORT 1025
ENTRYPOINT ["bin/maildev"]
HEALTHCHECK --interval=10s --timeout=1s \
  CMD wget -O - http://0.0.0.0:${MAILDEV_WEB_PORT}${MAILDEV_BASE_PATHNAME}/healthz || exit 1