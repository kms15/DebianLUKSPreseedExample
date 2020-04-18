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
  so read access to the install media (including knowledge of the initial
  passwords) does not present a security risk.  (Obviously write access to the
  install media always presents a security risk)

Instructions for use:
* Replace `authorized_keys` with your own ssh public keys
* Edit `autoinstall-preseed.m4`
   * change `my_username` and `my_fullname` to
     your preferred account names.
   * I would recommend not changing the passwords
     until after installation (to avoid storing plain-text passwords on the
     installation media).
   * Optionally set `my_install_target` to a different disk if you want to
     install the OS somewhere other than the first SATA drive (e.g.
     `/dev/nvme0`)
   * Make any other changes you would like to make to the preseed file.
* Run `make` to generate the so
* Optionally install KVM, and then run qemu-test to test the installation on a
  virtual machine.  The dropbear login ssh will be forwarded to
  `localhost` port `10023` and the normal ssh login to `localhost` port `10024`.
* Initially passwords for disk encryption and login are both "temp"; you will
  want to change these before exposing anything else to the network.
