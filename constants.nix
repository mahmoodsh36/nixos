rec {
  mahmooz3_addr = "95.217.163.31";
  # static addr..
  mahmooz2_addr = "192.168.1.2";
  mahmooz1_addr = "192.168.1.1"; # local for now
  # private_domain = "mahmooz3.lan";
  mydomain = "mahmoodsh.com";
  mygithub = "https://github.com/mahmoodsh36";
  myuser = "mahmooz";
  personal_website = "https://mahmoodsh36.github.io";
  ssh_pub_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICQaNODbg0EX196+JkADTx/cB0arDn6FelMGsa0tD0p6 mahmooz@mahmooz";
  home_dir = "/home/${myuser}";
  work_dir = "/home/${myuser}/work";
  scripts_dir = "${work_dir}/scripts";
  dotfiles_dir = "${work_dir}/otherdots";
  nix_config_dir = "${work_dir}/nixos/";
  blog_dir = "${work_dir}/blog";
  brain_dir = "${home_dir}/brain";
  music_dir = "${home_dir}/music";
  notes_dir = "${brain_dir}/notes";
  data_dir = "${home_dir}/data";
  extra_storage_dir = "${home_dir}/mnt2/my";
  mpv_socket_dir = "${data_dir}/mpv_data/sockets";
  mpv_main_socket_path = "${data_dir}/mpv_data/sockets/mpv.socket";
  main_key = "${brain_dir}/keys/hetzner1";
  enable_plasma = true;
  models_dir = if builtins.pathExists "${extra_storage_dir}"
               then "${extra_storage_dir}/jellyfin"
               else "/home/${myuser}/.jellyfin";
}