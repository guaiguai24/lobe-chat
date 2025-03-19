ARG NODEJS_VERSION="22"

FROM arm32v7/node:${NODEJS_VERSION}-slim AS base
ARG USE_CN_MIRROR
ENV DEBIAN_FRONTEND="noninteractive"
RUN \
    if [ "${USE_CN_MIRROR:-false}" = "true" ]; then \
        sed -i "s/deb.debian.org/mirrors.ustc.edu.cn/g" "/etc/apt/sources.list.d/debian.sources"; \
    fi \
    && apt update \
    && apt install -y ca-certificates proxychains-ng \
    && mkdir -p /distroless/bin /distroless/etc /distroless/etc/ssl/certs /distroless/lib \
    && cp /usr/lib/arm-linux-gnueabihf/libproxychains.so.4 /distroless/lib/libproxychains.so.4 \
    && cp /usr/lib/arm-linux-gnueabihf/libdl.so.2 /distroless/lib/libdl.so.2 \
    && cp /usr/bin/proxychains4 /distroless/bin/proxychains \
    && cp /etc/proxychains4.conf /distroless/etc/proxychains4.conf \
    && cp /usr/lib/arm-linux-gnueabihf/libstdc++.so.6 /distroless/lib/libstdc++.so.6 \
    && cp /usr/lib/arm-linux-gnueabihf/libgcc_s.so.1 /distroless/lib/libgcc_s.so.1 \
    && cp /usr/local/bin/node /distroless/bin/node \
    && cp /etc/ssl/certs/ca-certificates.crt /distroless/etc/ssl/certs/ca-certificates.crt \
    && rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/*

FROM base AS builder
WORKDIR /app
COPY package.json ./
COPY . ./
RUN npm install --legacy-peer-deps
RUN npm run build:docker

FROM arm32v7/busybox:latest AS app
COPY --from=base /distroless/ /
COPY --from=builder /app/.next/standalone /app/
COPY --from=builder /app/scripts/serverLauncher/startServer.js /app/startServer.js
RUN addgroup -S -g 1001 nodejs \
    && adduser -D -G nodejs -H -S -h /app -u 1001 nextjs \
    && chown -R nextjs:nodejs /app /etc/proxychains4.conf

FROM scratch
COPY --from=app / /
ENV NODE_ENV="production" \
    HOSTNAME="0.0.0.0" \
    PORT="3210"
EXPOSE 3210
USER nextjs
CMD ["node", "/app/startServer.js"]
