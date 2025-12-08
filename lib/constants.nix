rec {
  mahmooz3_addr = "199.247.22.252";
  # static addr..
  mahmooz2_addr = "192.168.1.2";
  mahmooz1_addr = "100.64.0.4"; # tailscale ip?
  # private_domain = "mahmooz3.lan";
  mydomain = "mahmoodsh.com";
  mygithub = "https://github.com/mahmoodsh36";
  personal_website = "https://mahmoodsh36.github.io";
  ssh_pub_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICQaNODbg0EX196+JkADTx/cB0arDn6FelMGsa0tD0p6 mahmooz@mahmooz";
  # TODO: get rid of the direct usage of /home here
  extra_storage_dir = "/home/mahmooz/mnt2/my/main";
  # main_key = "${brain_dir}/keys/hetzner1";
  enable_plasma = true;
  enable_gnome = true;
  models_dir = "${extra_storage_dir}/models";
}