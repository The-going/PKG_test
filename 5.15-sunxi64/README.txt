on the board:

git clone https://github.com/The-going/PKG_test deb
cd deb/5.15-sunxi64
sudo cp -p etc/kernel/postinst.d/zz-sync-dtb /etc/kernel/postinst.d/zz-sync-dtb

The script will copy the dtb files to the /boot/ directory.
In the future, you will not have to install the dtb package
and will be able to safely install two or three cores of
different branches (legacy, current, edge). But you will have
to fix symbolic links with your hands.

dpkg -i linux-image-current-sunxi64_22.05.0-trunk_arm64.deb

There is no need to install the linux-dtb-current-sunxi64_22.05.0-trunk_arm64.deb package.
Check and fix symbolic links manually in /boot/*
reboot
