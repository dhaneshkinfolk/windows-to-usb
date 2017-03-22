#!/bin/sh

#################################################################
## sudo apt-get install gparted grub-pc-bin p7zip-full ntfs-3g ##
#################################################################

# check for root privilages
if [ "$(id -u)" != "0" ]; then
    zenity --error --text="You must run this script as elevated user."
    exit 1
fi


# Disk Image
src_image=$(zenity --file-selection --file-filter='Iso images (*.iso)|*.iso *.ISO' --title="Please select a disk image")
if [ "$src_image" == "" ]; then
    zenity --error --text="Operation Cancelled by User"
    exit 2
fi


# Destination USB
device=$(ls -l /dev/disk/by-id/usb* | fgrep -v part | awk '{split($11,device,"/");split($9,id,"/");if(NR==1){print "TRUE\n" device[3] "\n" substr(id[5],5)}else{print "FALSE\n" device[3] "\n" substr(id[5],5)}}' | zenity --list --title="Select Target device" --text="Device List" --radiolist --column "Selection" --column "Device" --column "")
if [ "$device" == "" ]; then
    zenity --error --text="Operation Cancelled by User"
    exit 2
fi
umount /dev/$device?*
parted -s /dev/$device mklabel msdos
mount -a

usb_label=$(dd if="$src_image" bs=1 skip=32808 count=32)
if [ "$usb_label" == "" ]; then
    usb_label="Windows"
fi

#Create Partition /dev/${device}1
parted -s /dev/$device mkpart primary 1MiB 100%
#Format Partition /dev/${device}1
mkntfs -Q -v -F -L "$usb_label" /dev/${device}1
parted -s /dev/$device set 1 boot on

mnt_pnt=$(mktemp -d /tmp/usbwin.XXXXXXXXXX)
mount /dev/${device}1 $mnt_pnt
7z x "$src_image" -o${mnt_pnt}
if [ -d "${mnt_pnt}/BOOT" ]; then
  mv "${mnt_pnt}/BOOT" "${mnt_pnt}/boot"
fi

grub-install --target=i386-pc --boot-directory="${mnt_pnt}/boot" /dev/$device

cat << 'EOF' > ${mnt_pnt}/boot/grub/grub.cfg
menuentry 'Install Windows' {
	ntldr /bootmgr
}

EOF


umount $mnt_pnt/
rm -r $mnt_pnt/

success_message="Installation is Complete. You may boot your computer"
success_message="$success_message with this drive inserted to install Windows"
zenity --info --title "Installation Complete" \
		--text "$success_message"


