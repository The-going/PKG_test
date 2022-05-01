on the board:

git clone https://github.com/The-going/PKG_test deb
cd deb/nanpineo
sudo cp -p etc/kernel/postinst.d/zz-sync-dtb /etc/kernel/postinst.d/zz-sync-dtb

The script will copy the dtb files to the /boot/ directory.
In the future, you will not have to install the dtb package
and will be able to safely install two or three cores of
different branches (legacy, current, edge). But you will have
to fix symbolic links with your hands.

dpkg -i linux-image-edge-sunxi_22.05.0-trunk_armhf.deb

There is no need to install the linux-dtb-edge-sunxi_22.05.0-trunk_armhf.deb package.
Check and fix symbolic links manually in /boot/*
reboot
