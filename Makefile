TARGET=buster_autoinstall.iso
BUSTERURL=https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-10.3.0-amd64-netinst.iso

default: $(TARGET)

clean:
	rm -rf $(TARGET) iso qemu-test-image.qcow2

# download the base install image
buster_original.iso :
	wget $(BUSTERURL) -O $@

# extract the contents of the image
iso/README.txt : buster_original.iso
	mkdir -p iso
	cd iso && 7z x ../$<
	touch $@

# copy the preseed file to the appropriate location (using m4 to expand macros)
iso/preseed/autoinstall-preseed.seed: autoinstall-preseed.m4 iso/README.txt
	mkdir -p iso/preseed
	m4 -P $< > $@

# backup the old grub.cfg
iso/boot/grub/grub.cfg.orig: iso/README.txt
	cp iso/boot/grub/grub.cfg $@

# update the grub.cfg to include a menu option for a preseeded install
# (Used for UEFI)
iso/boot/grub/grub.cfg: grub.cfg.tail iso/boot/grub/grub.cfg.orig
	cp iso/boot/grub/grub.cfg.orig iso/boot/grub/grub.cfg
	cat grub.cfg.tail >> iso/boot/grub/grub.cfg

# backup the old isolinux.cfg
iso/isolinux/isolinux.cfg.orig: iso/README.txt
	cp iso/isolinux/isolinux.cfg $@

# update the grub.cfg to do a preseeded install
# (Used for Legacy BIOS)
iso/isolinux/isolinux.cfg : isolinux.cfg iso/isolinux/isolinux.cfg.orig
	cp $< $@

# include a list of initial authorized keys
iso/authorized_keys: authorized_keys
	cp $< $@

# generate the new iso install image
$(TARGET): iso/preseed/autoinstall-preseed.seed iso/boot/grub/grub.cfg iso/isolinux/isolinux.cfg iso/authorized_keys
	genisoimage -o $@ -b isolinux/isolinux.bin -c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table -J -R \
		-V "Debian Buster AutoInstall" iso

# create a virtual hard disk image for a qemu virtual machine for testing
qemu-test-image.qcow2 : $(TARGET)
	qemu-img create -f qcow2 $@ 8G

# Boot a qemu virtual machine using the new iso install file to test it
# Command-line notes: 512 MiB RAM, 1 CPU, KVM acceleration, forward
# localhost:10022 to guest port 22 (ssh) and localhost:10023 to guest port 23
# (dropbear ssh)
#
# Note that you can unlock VM in an automated fashion as follows:
# printf "temp" | ssh -o NoHostAuthenticationForLocalhost=True root@localhost -p 10023
#
qemu-test : qemu-test-image.qcow2 $(TARGET)
	qemu-system-x86_64 -hda $< -cdrom $(TARGET) -m 512M -smp 1 -accel kvm #\
#		-nic user,hostfwd=tcp:127.0.0.1:10022-:22,hostfwd=tcp:127.0.0.1:10023-:23 # -boot d
