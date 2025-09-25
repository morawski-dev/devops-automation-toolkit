FROM node:18-buster-slim AS builder

WORKDIR /app

COPY package.json yarn.lock ./
RUN yarn install
COPY . .
RUN yarn build


FROM node:18-buster-slim AS runner
WORKDIR /app

ENV NODE_ENV production
# Uncomment the following line in case you want to disable telemetry during runtime.
ENV NEXT_TELEMETRY_DISABLED 1

RUN addgroup --system --gid 15000 nodejs
RUN adduser --system --uid 15000 nextjs
RUN yarn add sharp next-logger@3.0.2
RUN apt-get update \
    && apt-get -y install curl \
    && apt-get install -y netcat  \
    && apt-get install -y cron  \
    && apt-get install -y logrotate  \
    && apt-get install -y  build-essential libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev librsvg2-dev \
    && rm -rf /var/lib/apt

# Configure log rotate
COPY etc/logrotate.d/ /etc/logrotate.d
RUN chmod 644 /etc/logrotate.d/portal  \
    && mkdir /var/log/portal \
    && chown nextjs:nodejs /app /var/log/portal \
    && echo "* * * * * /usr/sbin/logrotate /etc/logrotate.conf" >> /etc/cron.d/logrotate-cron \
    && crontab -u nextjs /etc/cron.d/logrotate-cron \
    && chmod u+s /usr/sbin/cron \
    && chmod u+s /usr/sbin/logrotate

# You only need to copy next.config.js if you are NOT using the default configuration
COPY --from=builder --chown=nextjs:nodejs /app/next.config.js ./
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json

# Automatically leverage output traces to reduce image size
# https://nextjs.org/docs/advanced-features/output-file-tracing
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --chown=nextjs:nodejs ./next-logger.config.js ./next-logger.config.js
COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER nextjs

EXPOSE 3000

ENV PORT 3000

ENTRYPOINT ["/entrypoint.sh"]