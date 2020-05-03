# DebianLUKSPreseedExample

This in an example of how to generate a Debian iso for a fully automated
install with full disk encryption, cobbled together from the Debian
documentation and several examples on the web.  It was created for my
personal use, but might be useful as an additional example or starting
point for others trying to set up automated Debian installs.

Features include:

* Single Make command to generate an install iso using the preseed file
  with your selected settings.
* Fully automated installation - no user interaction required
* Generates a minimal Debian install, but could easily be modified
  to include additional packages or generate an Ubuntu install.
* Installs a Dropbear ssh client for entering the LUKS decryption key
  remotely.
* Installs ssh to allow further remote configuration with tools such as
  Ansible.
* Both ssh servers are set up to require ssh public keys for authentication,
  so read access to the installation media (including knowledge of the initial
  passwords) does not present a security risk.  (Obviously write access to the
  install media always presents a security risk)
* The root account initially has an invalid password, and thus requires ssh
  access to login (you can change this in the preseed file if you need to be
  able to login from the console to do your initial configuration).

Instructions for use:
* Optional: edit `autoinstall-preseed.m4`
   * Can set `my_install_target` to a different disk if you want to
     install the OS somewhere other than the first SATA drive (e.g.
     `/dev/nvme0`)
   * Make any other changes you would like to make to the preseed file.
* Run `make` to generate debian_luks_autoinstall.iso.
* Optionally install KVM, and then run qemu-test to test the installation on a
  virtual machine.  The dropbear login ssh will be forwarded to
  `localhost` port `10023` and the normal ssh login to `localhost` port `10024`.
* Alternatively, use a tool like etcher or dd to copy the ISO to a USB flash
  drive and then boot a machine from this flash drive to install Debian.
* The LUKS drive can be unlocked either from the console or by using ssh to
  connect to port 23 with the matching ssh key, e.g.
  `ssh root@<your machine> -p 23 -i id_iso_root_rsa`.
* The root account can then be accessed via ssh on port 22 to continue your
  configuration e.g.
  `ssh root@<your machine> -p 22 -i id_iso_root_rsa`.  Obviously this can be
  automated with a tool such as ansible.
* The initial password for disk encryption is "temp"; you will
  want to change this before putting anything on the drive that you would like
  encryption to protect.
