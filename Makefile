TARGET_ISO=debian_luks_autoinstall.iso
DEBIAN_ISO_URL=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-10.3.0-amd64-netinst.iso
ISO_EXTRACTED_FLAG=iso/README.txt

default: $(TARGET_ISO)

clean:
	rm -rf $(TARGET_ISO) iso qemu-test-image.qcow2
	rm -rf id_iso_root_rsa{,.pub}

spotless:
	git clean -dffx
	git submodule foreach --recursive git clean -dffx

# download the base install image
debian_original.iso :
	wget $(DEBIAN_ISO_URL) -O $@

# extract the contents of the image
$(ISO_EXTRACTED_FLAG) : debian_original.iso
	mkdir -p iso
	cd iso && 7z x ../$<
	touch $@

# copy the preseed file to the appropriate location (using m4 to expand macros)
iso/preseed/autoinstall-preseed.seed: autoinstall-preseed.m4 \
		$(ISO_EXTRACTED_FLAG)
	mkdir -p iso/preseed
	m4 -P $< > $@

# backup the old grub.cfg
iso/boot/grub/grub.cfg.orig: $(ISO_EXTRACTED_FLAG)
	cp iso/boot/grub/grub.cfg $@

# update the grub.cfg to include a menu option for a preseeded install
# (Used for UEFI)
iso/boot/grub/grub.cfg: grub.cfg.tail iso/boot/grub/grub.cfg.orig
	cp iso/boot/grub/grub.cfg.orig iso/boot/grub/grub.cfg
	cat grub.cfg.tail >> iso/boot/grub/grub.cfg

# backup the old isolinux.cfg
iso/isolinux/isolinux.cfg.orig: $(ISO_EXTRACTED_FLAG)
	cp iso/isolinux/isolinux.cfg $@

# update the grub.cfg to do a preseeded install
# (Used for Legacy BIOS)
iso/isolinux/isolinux.cfg : isolinux.cfg iso/isolinux/isolinux.cfg.orig
	cp $< $@

# generate an ssh public/private key pair to use to access machines created
# with this iso
id_iso_root_rsa.pub: id_iso_root_rsa
id_iso_root_rsa:
	ssh-keygen -b 4096 -t RSA -N "" -C "iso-temporary-root-key" -f ./$@

# include the public temporary ssh key in the iso
iso/authorized_keys: id_iso_root_rsa.pub
	cp $< $@

# generate the new iso install image
$(TARGET_ISO): iso/preseed/autoinstall-preseed.seed iso/boot/grub/grub.cfg \
		iso/isolinux/isolinux.cfg iso/authorized_keys
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
# printf "temp" | ssh root@localhost -p 10023 -i id_iso_root_rsa
#
qemu-test : qemu-test-image.qcow2 $(TARGET_ISO)
	qemu-system-x86_64 -hda $< -cdrom $(TARGET_ISO) -m 512M -smp 1 -accel kvm \
		-nic user,hostfwd=tcp:127.0.0.1:10022-:22,hostfwd=tcp:127.0.0.1:10023-:23 \
		-curses # -boot d
