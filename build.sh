#!/bin/bash

set -ex

function build_debian_post_chroot {

	sudo mount -t proc	chproc	rootfs/proc
	sudo mount -t sysfs	chsys	rootfs/sys

	sudo chroot rootfs /bin/bash <<EOF
echo -e "chip\nchip\n\n\n\n\n\nY\n" | adduser chip
adduser chip sudo

apt-get clean
apt-get autoclean
apt-get autoremove

rm -rf /var/lib/apt/lists/*
rm -rf /usr/lib/locale/*
EOF
  sync
  sleep 3

#  sudo umount -l rootfs/dev/pts
#  sudo umount -l rootfs/dev
  sudo umount -l rootfs/proc
  sudo umount -l rootfs/sys

  sudo rm rootfs/usr/sbin/policy-rc.d
  sudo rm rootfs/etc/resolv.conf
  sudo rm rootfs/usr/bin/qemu-arm-static

	#  hack to generate ssh host keys on first boot
	if [[ ! -e rootfs/etc/rc.local.orig ]]; then sudo mv rootfs/etc/rc.local rootfs/etc/rc.local.orig; fi
	echo -e "#!/bin/sh\n\n\
rm -f /etc/ssh/ssh_host_*\n\
/usr/bin/ssh-keygen -t rsa -N '' -f /etc/ssh/ssh_host_rsa_key\n\
/usr/bin/ssh-keygen -t dsa -N '' -f /etc/ssh/ssh_host_dsa_key\n\
/usr/bin/ssh-keygen -t rsa1 -N '' -f /etc/ssh/ssh_host_key\n\
/usr/bin/ssh-keygen -t ecdsa -N '' -f /etc/ssh/ssh_host_ecdsa_key\n\
/usr/bin/ssh-keygen -t ed25519 -N '' -f /etc/ssh/ssh_host_ed25519_key\n\
systemctl restart ssh\n\
mv -f /etc/rc.local.orig /etc/rc.local\n" |sudo tee rootfs/etc/rc.local >/dev/null
	sudo chmod a+x rootfs/etc/rc.local

	#enable root login via ssh
	sudo sed -i -e 's/PermitRootLogin without-password/PermitRootLogin yes/' rootfs/etc/ssh/sshd_config

	#network-manager should ignore wlan1
	NM_CONF="rootfs/etc/NetworkManager/NetworkManager.conf"
	grep -q '^\[keyfile\]' "${NM_CONF}" || \
    echo -e "$(cat ${NM_CONF})\n\n[keyfile]\nunmanaged-devices=interface-name:wlan1" |sudo tee ${NM_CONF}

  #hack to set back kernel/printk level to 4 after wifi modules have been loaded:
  sudo sed -i -e '/ExecStart=.*/ aExecStartPost=/bin/bash -c "/bin/echo 4 >/proc/sys/kernel/printk"' rootfs/lib/systemd/system/wpa_supplicant.service

  #load g_serial at boot time
  echo -e "$(cat rootfs/etc/modules)\ng_serial" | sudo tee rootfs/etc/modules

  echo -e "Debian on C.H.I.P ${BRANCH} build ${BUILD} rev ${GITHASH}\n" |sudo tee rootfs/etc/chip_build_info.txt

echo -e "$(cat rootfs/etc/os-release)\n\
BUILD_ID=$(date)\n\
VARIANT=\"Debian on C.H.I.P\"\n\
VARIANT_ID=$(cat rootfs/etc/os-variant)\n" |sudo tee rootfs/etc/os-release

#sudo chown -R $USER:$USER *

#sudo rm -rf rootfs/proc/*
#sudo rm -rf rootfs/dev/*
#sudo rm -rf rootfs/run/*
#sudo rm -rf rootfs/sys/*

sudo tar -zcf postchroot-rootfs.tar.gz rootfs
}

build_debian_post_chroot || exit $?

