FROM alpine:latest
RUN apk --update add git build-base linux-headers
# Build afl
COPY ./afl-2.51b /tmp/afl-2.51b
RUN cd /tmp/afl-2.51b && make && make install

# Build busybox. Source depends on whatever is on the src busybox.
#
# ***** N O T I C E *****
#
# Edit the Makefile and change gcc to afl-gcc and g++ to afl-g++
#
# ***********************


COPY ./busybox /busybox

WORKDIR /busybox

# Build busybox *with the same conf as the official Docker image*
RUN set -ex; \
    \
    setConfs=' \
        CONFIG_AR=y \
        CONFIG_FEATURE_AR_CREATE=y \
        CONFIG_FEATURE_AR_LONG_FILENAMES=y \
        CONFIG_LAST_SUPPORTED_WCHAR=0 \
        CONFIG_STATIC=y \
    '; \
    \
    unsetConfs=' \
        CONFIG_FEATURE_SYNC_FANCY \
    '; \
    \
    make defconfig; \
    \
    for conf in $unsetConfs; do \
        sed -i \
            -e "s!^$conf=.*\$!# $conf is not set!" \
            .config; \
    done; \
    \
    for confV in $setConfs; do \
        conf="${confV%=*}"; \
        sed -i \
            -e "s!^$conf=.*\$!$confV!" \
            -e "s!^# $conf is not set\$!$confV!" \
            .config; \
        if ! grep -q "^$confV\$" .config; then \
            echo "$confV" >> .config; \
        fi; \
    done; \
    \
    make oldconfig; \
    \
# trust, but verify
    for conf in $unsetConfs; do \
        ! grep -q "^$conf=" .config; \
    done; \
    for confV in $setConfs; do \
        grep -q "^$confV\$" .config; \
    done;

# Running with -j1 until figures out anything better
RUN set -ex; make -j1 busybox

# ENTRYPOINT ["/busybox/busybox", "sh"]
# remember: for i in /corpus/*; do afl-tmin -i $i -o $i.min -- /busybox/busybox unzip @@ -oqd /tmp; done;
ENTRYPOINT ["afl-fuzz", "-i", "/corpus/", "-o", "/outdir", "/busybox/busybox", "unzip" , "@@", "-oqd", "/tmp"]
