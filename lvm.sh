#!/bin/bash

### Creating temporary volume with xfs and mount
sudo -i
pvcreate /dev/sdb
vgcreate vg_root /dev/sdb
lvcreate -n lv_root -l +100%FREE /dev/vg_root
mkfs.xfs /dev/vg_root/lv_root
mount /dev/vg_root/lv_root /mnt

# Copy files from / to /mnt
xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
ls -la /mnt

# Reconfiguration grub and initrd
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
chroot /mnt/
grub2-mkconfig -o /boot/grub2/grub.cfg
cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g;s/.img//g"` --force; done
sed -i 's+rd.lvm.lv=VolGroup00/LogVol00+rd.lvm.lv=vg_root/lv_root+g' ./grub2/grub.cfg

# Exit from chroot and reboot
exit
shutdown -r now

# Resizing LogVol00
sudo -i
lvremove -y /dev/VolGroup00/LogVol00
lvcreate -y -n VolGroup00/LogVol00 -L 8G /dev/VolGroup00
mkfs.xfs /dev/VolGroup00/LogVol00
mount /dev/VolGroup00/LogVol00 /mnt
xfsdump -J - /dev/vg_root/lv_root | xfsrestore -J - /mnt

# Reconfiguration grub and initrd
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
chroot /mnt/
grub2-mkconfig -o /boot/grub2/grub.cfg
cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g;s/.img//g"` --force; done

# Moving /var
pvcreate /dev/sdc /dev/sdd
vgcreate vg_var /dev/sdc /dev/sdd
lvcreate -y -L 950M -m1 -n lv_var vg_var
mkfs.ext4 /dev/vg_var/lv_var
mount /dev/vg_var/lv_var /mnt
cp -aR /var/* /mnt/
mkdir /tmp/oldvar
mv /var/* /tmp/oldvar
umount /mnt
mount /dev/vg_var/lv_var /var
echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab

# Exit from chroot and reboot
exit
shutdown -r now

# Moving /home
sudo -i
lvremove -y /dev/vg_root/lv_root
vgremove /dev/vg_root
pvremove /dev/sdb
lvcreate -n LogVol_Home -L 2G /dev/VolGroup00
mkfs.xfs /dev/VolGroup00/LogVol_Home
mount /dev/VolGroup00/LogVol_Home /mnt/
cp -aR /home/* /mnt/
rm -rf /home/*
umount /mnt
mount /dev/VolGroup00/LogVol_Home /home/
echo "`blkid | grep Home | awk '{print $2}'` /home xfs defaults 0 0" >> /etc/fstab

### Working with snapshot
touch /home/file{1..20}
ls -la /home
lvcreate -L 100MB -s -n home_snap /dev/VolGroup00/LogVol_Home
lsblk
touch /home/snap-file{1..20}
rm -f /home/file{11..20}
ls -la /home
umount /home
lvconvert --merge /dev/VolGroup00/home_snap
mount /home
ls -la /home
lvremove /dev/VolGroup00/home_snap
ls -la /home