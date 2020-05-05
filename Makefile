TARGET_ISO=debian_luks_autoinstall.iso
DEBIAN_ISO_URL=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-10.3.0-amd64-netinst.iso
ISO_EXTRACTED_TAG=iso/README.txt
TFTP_COMPLETE_TAG=tftp/autoinstall.txt

default: $(TARGET_ISO) $(TFTP_COMPLETE_TAG)

clean:
	rm -rf $(TARGET_ISO)
	rm -rf iso
	rm -rf id_installer_rsa id_installer_rsa.pub
	rm -rf initrd.pxe tftp
	rm -rf qemu-test-image.qcow2 qemu-pxe-test-image.qcow2

spotless:
	git clean -dffx
	git submodule foreach --recursive git clean -dffx

# generate an ssh public/private key pair to use to access machines created
# with this preseed file
id_installer_rsa.pub: id_installer_rsa
id_installer_rsa:
	ssh-keygen -b 4096 -t RSA -N "" -C "iso-temporary-root-key" -f ./$@


#########################################################
# ISO target
#########################################################

# download the base install image
debian_original.iso :
	wget $(DEBIAN_ISO_URL) -O $@

# extract the contents of the image
$(ISO_EXTRACTED_TAG) : debian_original.iso
	mkdir -p iso
	cd iso && 7z x ../$<
	touch $@

# copy the preseed file to the appropriate location (using m4 to expand macros)
iso/preseed/autoinstall-preseed.seed : autoinstall-preseed.m4 \
		$(ISO_EXTRACTED_TAG) id_installer_rsa.pub
	mkdir -p iso/preseed
	m4 -P $< > $@
	sed -i -e "s#REPLACE_WITH_SSH_PUBLIC_KEY#$$(cat id_installer_rsa.pub)#g" $@

# update the grub.cfg to include a menu option for a preseeded install
# (Used for UEFI)
iso/boot/grub/grub.cfg : grub.cfg $(ISO_EXTRACTED_TAG)
	cp $< $@

# update the isolinux.cfg to do a preseeded install
# (Used for Legacy BIOS)
iso/isolinux/isolinux.cfg : isolinux.cfg $(ISO_EXTRACTED_TAG)
	cp $< $@

# generate the new iso install image
$(TARGET_ISO) : iso/preseed/autoinstall-preseed.seed iso/boot/grub/grub.cfg \
		iso/isolinux/isolinux.cfg
	genisoimage -o $@ -b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table -J -R \
		-V "Debian AutoInstall" iso

# create a virtual hard disk image for a qemu virtual machine for testing
qemu-test-image.qcow2 : $(TARGET_ISO)
	qemu-img create -f qcow2 $@ 8G

# Boot a qemu virtual machine using the new iso install file to test it
# Command-line notes: 512 MiB RAM, 1 CPU, KVM acceleration, forward
# localhost:10022 to guest port 22 (ssh) and localhost:10023 to guest port 23
# (dropbear ssh)
#
# Note that you can unlock the VM in an automated fashion as follows:
# printf "temp" | ssh root@localhost -p 10023 -i id_installer_rsa
#
qemu-test : qemu-test-image.qcow2 $(TARGET_ISO)
	qemu-system-x86_64 -hda $< -cdrom $(TARGET_ISO) -m 512M -smp 1 -accel kvm \
		-nic user,hostfwd=tcp:127.0.0.1:10022-:22,hostfwd=tcp:127.0.0.1:10023-:23 \
		-curses # -boot d

#########################################################
# PXE (network boot) target
#########################################################

DEBIAN_NETBOOT_URL=https://cdimage.debian.org/debian/dists/stable/main/installer-amd64/current/images/netboot/netboot.tar.gz
TFTP_TAG=tftp/version.info
INITRD_PXE_TAG=initrd.pxe/init

# download the base netboot image
netboot.tar.gz :
	wget $(DEBIAN_NETBOOT_URL) -O $@

# extract the netboot image
$(TFTP_TAG) : netboot.tar.gz
	mkdir -p tftp
	cd tftp && tar -xzf ../netboot.tar.gz
	touch $@

# extract the initrd.gz file (part of the netboot image)
tftp/debian-installer/amd64/initrd.gz : $(TFTP_TAG)

# extract the contents of the initrd.gz file to the initrd.pxe directory
$(INITRD_PXE_TAG) : tftp/debian-installer/amd64/initrd.gz
	mkdir -p initrd.pxe
	cd initrd.pxe && gzip -d < ../$< | fakeroot cpio -id
	touch $@

# copy the preseed file into the initrd.pxe tree
initrd.pxe/preseed.cfg : autoinstall-preseed.m4 \
		$(INITRD_PXE_TAG)
	m4 -P $< > $@
	sed -i -e "s#REPLACE_WITH_SSH_PUBLIC_KEY#$$(cat id_installer_rsa.pub)#g" $@

# create a pxelinux.cfg to boot using the new initrd
tftp/pxelinux.cfg/default: pxelinux.cfg.default $(TFTP_TAG)
	cp $< $@

# recompress the initrd.pxe directory to create a new initrd with the preseed
tftp/debian-installer/amd64/initrd0.gz : initrd.pxe/preseed.cfg $(TFTP_TAG)
	cd initrd.pxe && find . | fakeroot cpio -o -H newc | gzip > ../$@

$(TFTP_COMPLETE_TAG) : tftp/debian-installer/amd64/initrd0.gz tftp/pxelinux.cfg/default
	echo "Configured for autoinstall on $$(date)" > $@

# create a virtual hard disk image for a qemu virtual machine for testing
qemu-pxe-test-image.qcow2 : $(TARGET_ISO)
	qemu-img create -f qcow2 $@ 8G

# Boot a qemu virtual machine using the new network boot files to test them
# Command-line notes: 512 MiB RAM, 1 CPU, KVM acceleration, forward
# localhost:10024 to guest port 22 (ssh) and localhost:10025 to guest port 23
# (dropbear ssh)
#
# Note that you can unlock the VM in an automated fashion as follows:
# printf "temp" | ssh root@localhost -p 10025 -i id_installer_rsa
#
qemu-pxe-test : qemu-pxe-test-image.qcow2 $(TFTP_COMPLETE_TAG)
	qemu-system-x86_64 -hda $< -m 512M -smp 1 -accel kvm -boot cn \
		-nic user,hostfwd=tcp:127.0.0.1:10024-:22,hostfwd=tcp:127.0.0.1:10025-:23,tftp=./tftp,bootfile=/pxelinux.0 \
		-curses # -boot d
