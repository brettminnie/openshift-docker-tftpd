ARG BUILD_IMAGE="registry.microlise.com/platform-base/almalinux:8-minimal"
FROM ${BUILD_IMAGE} as STAGING
WORKDIR /tmp
RUN microdnf install -y rpm dnf-utils cpio && \
    yumdownloader shim-x64 grub2-efi-x64 syslinux-nonlinux syslinux && \
    rpm2cpio shim*.rpm | cpio -dimvu && \
    rpm2cpio grub2*.rpm | cpio -dimvu && \
    rpm2cpio syslinux-6*.rpm | cpio -dimvu && \
    rpm2cpio syslinux-nonlinux*.rpm | cpio -dimvu && \
    mkdir -p /config/grub2 && \
    cp /tmp/boot/efi/EFI/almalinux/{grubx64.efi,shimx64.efi} /config/grub2/ && \
    cp /tmp/usr/share/syslinux/{pxelinux.0,menu.c32,vesamenu.c32,ldlinux.c32,libcom32.c32,libutil.c32} /config/ && \
    rm -rf /tmp/* && \
    microdnf clean all


FROM ${BUILD_IMAGE}
COPY container_resources/entrypoint.sh /usr/sbin/

RUN microdnf update -y && \
    microdnf install -y epel-release && \
    microdnf install -y tftp-server && \
    mkdir -p /config/{pxelinux.cfg,rhcos,grub2} && \
    chown -R ftp:ftp $_ && \
    microdnf clean all && \
    rm -rf /usr/local/share/man/* && \
    rm -rf /tmp/* && \
    chmod +x /usr/sbin/entrypoint.sh && \
    touch /var/log/messages && \
    ln -sf /proc/1/fd/1 /var/log/messages

COPY --from=STAGING /config/ /config/

RUN chown -R ftp:ftp /config && \
    chown ftp:ftp /var/log/messages && \
    chmod -R 775 /config

STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/sbin/entrypoint.sh"]
CMD ["/usr/sbin/in.tftpd", "-L", "-u", "ftp", "-s", "/config", "-vvvv", "-t", "300", "-p", "-4"]
