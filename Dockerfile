# Asterisk 22 (LTS) با chan_websocket + res_websocket_client
# تصویر پایه برای سرویس داکر چابکان (Dograh ARI + ترانک SIP)
ARG ASTERISK_REF=22

FROM debian:bookworm-slim AS builder
ARG ASTERISK_REF
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential git ca-certificates curl wget patch \
      pkg-config autoconf automake libtool bison flex \
      libssl-dev libxml2-dev libsqlite3-dev libedit-dev uuid-dev \
      libjansson-dev libncurses-dev libsrtp2-dev libcurl4-openssl-dev \
      libcap-dev libnewt-dev liblua5.3-dev python3 bzip2 \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "${ASTERISK_REF}" \
      https://github.com/asterisk/asterisk.git /usr/src/asterisk \
 && cd /usr/src/asterisk \
 && ./configure --with-pjproject-bundled --without-dahdi --disable-xmldoc \
 && ( make menuselect.makeopts || echo "check-deps non-zero (expected)" ) \
 && test -f menuselect.makeopts \
 && menuselect/menuselect \
      --enable chan_websocket \
      --enable res_websocket_client \
      --enable res_http_websocket \
      --disable-category MENUSELECT_CORE_SOUNDS \
      --disable-category MENUSELECT_MOH \
      --disable-category MENUSELECT_EXTRA_SOUNDS \
      --disable BUILD_NATIVE \
      menuselect.makeopts \
 && make -j"$(nproc)" \
 && make install DESTDIR=/opt/asterisk \
 && test -f /opt/asterisk/usr/lib/asterisk/modules/chan_websocket.so \
 && test -f /opt/asterisk/usr/lib/asterisk/modules/res_websocket_client.so \
 && ls /opt/asterisk/usr/lib/asterisk/modules | wc -l

FROM debian:bookworm-slim
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Tehran
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates tzdata gettext-base \
      libedit2 libssl3 libxml2 libsqlite3-0 libuuid1 libjansson4 \
      libncurses6 libsrtp2-1 libcurl4 libcap2 libnewt0.52 \
      libodbc2 liblua5.3-0 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /opt/asterisk/ /

RUN groupadd -r asterisk 2>/dev/null || true \
 && useradd -r -g asterisk -d /var/lib/asterisk -s /usr/sbin/nologin asterisk 2>/dev/null || true \
 && mkdir -p /etc/asterisk /var/lib/asterisk /var/log/asterisk \
            /var/spool/asterisk /var/run/asterisk /usr/lib/asterisk \
 && chown -R asterisk:asterisk /etc/asterisk /var/lib/asterisk \
      /var/log/asterisk /var/spool/asterisk /var/run/asterisk

EXPOSE 8088/tcp 5060/udp 10000-10100/udp
CMD ["asterisk", "-f", "-U", "asterisk", "-G", "asterisk", "-vvv"]
