rec {
  mahmooz3_addr = "95.179.250.73";
  # assigned by headscale at registration, stable unless the node is re-registered.
  mahmooz3_tailnet_addr = "100.64.0.1";
  # static addr..
  mahmooz2_addr = "192.168.1.2";
  mahmooz4_addr = "mahmooz4.tailnet.${mydomain}";
  # mahmooz4_addr = "10.0.0.4";
  # private_domain = "mahmooz3.lan";
  mydomain = "mahmoodsh.com";
  blocky_port = 53;
  mygithub = "https://github.com/mahmoodsh36";
  personal_website = "https://mahmoodsh36.github.io";
  ssh_pub_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICQaNODbg0EX196+JkADTx/cB0arDn6FelMGsa0tD0p6 mahmooz@mahmooz";
  password = "mahmooz";
  # gpt partuuids of the usb image (the esp one is fixed by nixpkgs make-disk-image.nix)
  usb_root_partuuid = "F222513B-DED1-49FA-B591-20CE86A2FE7F";
  usb_esp_partuuid = "1C06F03B-704E-4657-B9CD-681A087A2FDC";
}