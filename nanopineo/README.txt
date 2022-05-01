on the board:

git clone https://github.com/The-going/PKG_test deb
cd deb
sudo cp -p etc/kernel/postinst.d/zz-sync-dtb /etc/kernel/postinst.d/zz-sync-dtb

dpkg -i linux-image-edge-sunxi_22.05.0-trunk_armhf.deb

There is no need to install the linux-dtb-edge-sunxi_22.05.0-trunk_armhf.deb package.
Check and fix symbolic links manually in /boot/*
reboot
