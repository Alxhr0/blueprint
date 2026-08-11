#!/bin/bash
set -eoux pipefail

pushd /usr/lib/kernel/install.d
if [ -f 05-rpmostree.install ]; then
    mv 05-rpmostree.install 05-rpmostree.install.bak
fi
if [ -f 50-dracut.install ]; then
    mv 50-dracut.install 50-dracut.install.bak
fi
printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install
printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install
chmod +x 05-rpmostree.install 50-dracut.install
popd

for pkg in kernel kernel{-core,-modules,-modules-core,-modules-extra,-devel,-devel-matched,-tools-libs,-tools}; do
    rpm --erase "${pkg}" --nodeps || true
done

rm -rf /usr/lib/modules

dnf5 -y install \
    /tmp/kernel-rpms/kernel-[0-9]*.rpm \
    /tmp/kernel-rpms/kernel-core-*.rpm \
    /tmp/kernel-rpms/kernel-modules-*.rpm \
    /tmp/kernel-rpms/kernel-devel-*.rpm

dnf5 versionlock add \
    kernel kernel-devel kernel-devel-matched kernel-core \
    kernel-modules kernel-modules-core kernel-modules-extra

dnf5 -y install /tmp/rpms/ublue-os/ublue-os-akmods-addons-*.rpm

/ctx/install-kmods \
    /tmp/rpms/{common,kmods}/*framework-laptop*.rpm \
    /tmp/rpms/{common,kmods}/*v4l2loopback*.rpm \
    /tmp/rpms/{common,kmods}/*xone*.rpm \
    /tmp/rpms/{common,kmods}/*xpadneo*.rpm \
    /tmp/rpms/{common,kmods}/*wl*.rpm

/ctx/install-kmods \
    /tmp/rpms/{extra,kmods-extra}/*zenergy*.rpm \
    /tmp/rpms/{extra,kmods-extra}/*gcadapter*.rpm \
    /tmp/rpms/{extra,kmods-extra}/*kvmfr*.rpm \
    /tmp/rpms/{extra,kmods-extra}/*new-lg4ff*.rpm \
    /tmp/rpms/{extra,kmods-extra}/*hid-tmff2*.rpm \
    /tmp/rpms/{extra,kmods-extra}/*t150-driver*.rpm \
    /tmp/rpms/{extra,kmods-extra}/*hid-fanatecff*.rpm \
    /tmp/rpms/{extra,kmods-extra}/*sc0710*.rpm \
    /tmp/rpms/{extra,kmods-extra}/*system76*.rpm

pushd /usr/lib/kernel/install.d
[ -f 05-rpmostree.install.bak ] && mv -f 05-rpmostree.install.bak 05-rpmostree.install
[ -f 50-dracut.install.bak ] && mv -f 50-dracut.install.bak 50-dracut.install
popd
