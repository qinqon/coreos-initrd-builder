ARG BASE
ARG LABEL
ARG TOOLBOX
FROM $TOOLBOX as build

ARG AFTERBURN_COMMIT

RUN dnf install -y openssl-devel make git gcc rust cargo

RUN git clone https://github.com/qinqon/afterburn.git /afterburn && \
    cd /afterburn && \
    git checkout ${AFTERBURN_COMMIT}

RUN  make -C /afterburn

FROM $BASE

COPY --from=build /afterburn/target/release/afterburn /usr/bin/afterburn
COPY --from=build /afterburn/dracut/30afterburn/* /usr/lib/dracut/modules.d/30afterburn

RUN set -xeuo pipefail && \
    KERNEL_VERSION="$(basename $(ls -d /lib/modules/*))" && \
    raw_args="$(lsinitrd /lib/modules/${KERNEL_VERSION}/initramfs.img | grep '^Arguments: ' | sed 's/^Arguments: //')" && \
    stock_arguments=$(echo "$raw_args" | sed "s/'//g") && \
    echo "Using kernel: $KERNEL_VERSION" && \
    echo "Dracut arguments: $stock_arguments" && \
    mkdir -p /tmp/dracut /var/roothome && \
    dracut $stock_arguments && \
    mv -v /boot/initramfs*.img "/lib/modules/${KERNEL_VERSION}/initramfs.img" && \
    ostree container commit

LABEL com.coreos.osname=$LABEL
