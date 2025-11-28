#!/bin/bash
#Script for resizing root partition
##Create temporary physical volume group
###Get unmounted devices
devices=$(lsblk -d -o NAME,SIZE,TYPE | grep disk)
echo "Available devices:"
echo "$devices"
###Device select
read -p "Enter full device name: " devname
###Physical volume creation
pvcreate $devname
##Create volume group
read -p "Enter volume group name: " vgname
vgcreate $vgname $devname
##Create logical volume
read -p "Enter logical volume name and desirable size in percent of free extents (digits only): " lvname lvsize
lvcreate --yes -n $lvname -l +$lvsize%FREE $vgname
##Create EXT4 Filesystem
mkfs.ext4 /dev/$vgname/$lvname
##Mount partition
read -p "Enter mountpath: " mountpath
mount -m /dev/$vgname/$lvname $mountpath
##Disable swap to save space
swapoff /swap.img
rm -f /swap.img
sed -i '/\sswap\s/d' /etc/fstab
##Copy root partition without mounted partitions
rsync -avxHAX --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} --progress / $mountpath
##Mount system partitions to new root partition
for i in /proc/ /sys/ /dev/ /run/ /boot/; do 
  mount --bind $i $mountpath/$i
 done
##Change root directory to new and update GRUB and initrd inside chroot
chroot "$mountpath" bash -c '
grub-mkconfig -o /boot/grub/grub.cfg
update-initramfs -u
'





