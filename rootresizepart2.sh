#!/bin/bash
#Script for resizing root partition part 2 and creating new partitions for /var and /home
##Change old logical volume size
###Get available logical volumes
volumes=$(lvdisplay | grep "LV Path" | awk '{print $3}')
echo "Available volumes:"
echo "$volumes"
###Re-create volume
read -p "Enter full volume name and desired size (in megabytes or gigabytes, for example, 2000M or 10G): " fulllvname lvsize
vgname="$(echo "$fulllvname" | cut -d'/' -f3)"
lvname="$(echo "$fulllvname" | cut -d'/' -f4)"
lvremove --yes $fulllvname
lvcreate --yes -n $lvname -L $lvsize /dev/$vgname
mkfs.ext4 $fulllvname
read -p "Enter mountpath: " mountpath
mount -m $fulllvname $mountpath
##Copy root partition without mounted partitions
rsync -avxHAX --exclude={"/dev/*","/proc/*","/sys/*","/tmp/*","/run/*","/mnt/*","/media/*","/lost+found"} --progress / $mountpath
##Mount system partitions to new root partition
for i in /proc/ /sys/ /dev/ /run/ /boot/; do 
  mount --bind $i $mountpath/$i
 done
 ##Change root directory to new and update GRUB and initrd inside chroot, create lvm mirror, volume and filesystem for /var, move files to new volume 
chroot "$mountpath" bash -c '
grub-mkconfig -o /boot/grub/grub.cfg
update-initramfs -u
devices=$(lsblk -d -o NAME,SIZE,TYPE | grep disk)
echo "Available devices:"
echo "$devices"
read -p "Select two devices for /var partition: " dev1 dev2
pvcreate $dev1 $dev2
vgcreate vg_var $dev1 $dev2
read -p "Enter size for /var partition (in megabytes or gigabytes, for example, 2000M or 10G)": varsize
lvcreate -L $varsize -m1 -n lv_var vg_var
mkfs.ext4 /dev/vg_var/lv_var
mount -m /dev/vg_var/lv_var /mnt/var
cp -aR /var/* /mnt/var
umount /mnt/var
mount /dev/vg_var/lv_var /var
'
###Add record to fstab for new /var volume
varuuid=$(blkid /dev/vg_var/lv_var | awk '{print $2}')
echo "$varuuid /var ext4 defaults 0 0" >> $mountpath/etc/fstab
###Create /home volume in the same volume group as / directory, move files and make new record in fstab
echo "Available free space on volume group $(vgs $vgname --noheadings -o vg_free)"
read -p "Enter /home logical volume size (in megabytes or gigabytes, for example, 2000M or 10G): " homesize
lvcreate -n lv_home -L $homesize /dev/$vgname
mkfs.ext4 /dev/$vgname/lv_home
mount -m /dev/$vgname/lv_home /mnt/home
cp -aR /home/* /mnt/home
rm -rf /home/*
umount /mnt/home
mount /dev/$vgname/lv_home /home
homeuuid=$(blkid /dev/$vgname/lv_home | awk '{print $2}')
echo "$homeuuid /home ext4 defaults 0 0" >> $mountpath/etc/fstab

