FROM ubuntu:resolute AS build

ARG DOVECOT_VERSION
ARG WORMHOLE_VERSION

# wormhole is the third-party revival of the replicator Dovecot dropped. It is
# not packaged anywhere, so it is built here against the headers of the exact
# Dovecot the runtime stage installs: the plugin links against Dovecot's
# internal ABI and a mismatch fails at load, not at build. dovecot-core is a
# build dependency too, not just a runtime one — configure runs doveconf to
# read the server's own build settings.
RUN test -n "${DOVECOT_VERSION}" && test -n "${WORMHOLE_VERSION}" \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
      autoconf \
      automake \
      build-essential \
      ca-certificates \
      dovecot-core=${DOVECOT_VERSION} \
      dovecot-dev=${DOVECOT_VERSION} \
      git \
      libtool \
      pkg-config \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth 1 --branch "v${WORMHOLE_VERSION}" \
      https://codeberg.org/errror/wormhole.git /usr/src/wormhole

WORKDIR /usr/src/wormhole
RUN if [ ! -x ./configure ]; then autoreconf -fi; fi \
    && ./configure --prefix=/usr \
    && make \
    && make install DESTDIR=/out

FROM ubuntu:resolute

ARG DOVECOT_VERSION
ARG WORMHOLE_VERSION
LABEL org.opencontainers.image.title="dovecot container"
LABEL org.opencontainers.image.description="Dovecot with the wormhole replication plugin, from the Ubuntu packages"
LABEL org.opencontainers.image.source="https://github.com/slim-it/dovecot-container"
# The tag is a single ordered version (see README), so these labels are where
# a reader finds out what a given image actually contains. They carry the full
# packaged versions, including the packaging revision the tag drops. The
# standard image.version annotation is not used for either: CI overwrites it
# with the tag.
LABEL nl.slim-it.dovecot.version="${DOVECOT_VERSION}"
LABEL nl.slim-it.wormhole.version="${WORMHOLE_VERSION}"

# curl is the spam-training path: the IMAPSieve hooks post messages to
# rspamd's controller rather than pulling in the whole rspamd server for its
# client binary.
RUN test -n "${DOVECOT_VERSION}" \
    && apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
      ca-certificates \
      curl \
      dovecot-core=${DOVECOT_VERSION} \
      dovecot-flatcurve=${DOVECOT_VERSION} \
      dovecot-imapd=${DOVECOT_VERSION} \
      dovecot-lmtpd=${DOVECOT_VERSION} \
      dovecot-mysql=${DOVECOT_VERSION} \
      dovecot-sieve=${DOVECOT_VERSION} \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /out/ /

ENTRYPOINT ["/usr/sbin/dovecot", "-F"]
