ARG BASE
ARG LABEL
ARG TOOLBOX
FROM $TOOLBOX as afterburn-build

ARG AFTERBURN_COMMIT

RUN dnf install -y openssl-devel make git gcc rust cargo

RUN git clone https://github.com/qinqon/afterburn.git /afterburn && \
    cd /afterburn && \
    git checkout ${AFTERBURN_COMMIT}

RUN  make -C /afterburn

FROM $TOOLBOX as ignition-build

ARG IGNITION_COMMIT

RUN dnf install -y make git golang libblkid-devel

RUN git clone https://github.com/qinqon/ignition.git /ignition && \
    cd /ignition && \
    git checkout ${IGNITION_COMMIT}

RUN  make -C /ignition

FROM $BASE

COPY --from=afterburn-build /afterburn/target/release/afterburn /usr/bin/afterburn
COPY --from=afterburn-build /afterburn/dracut/30afterburn/* /usr/lib/dracut/modules.d/30afterburn

COPY --from=ignition-build /ignition/bin/amd64/ignition /usr/bin/ignition
COPY --from=ignition-build /ignition/bin/amd64/ignition /usr/lib/dracut/modules.d/30ignition/ignition

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
