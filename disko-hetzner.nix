{ config, pkgs, lib, ... }:

{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        # !!! ADAPT THIS DEVICE PATH !!!
        device = "/dev/sda"; # Or /dev/sda, etc.
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              label = "ESP";
              name = "ESP";
              size = "512M";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              label = "root";
              name = "root";
              size = "100%";
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
            # swap = { ... };
          };
        };
      };
    };
    # nodev."/" = { ... } # Explicit filesystem definitions if needed
    # nodev."/boot" = { ... }
  };

  # You might still define fileSystems here if Disko doesn't infer
  # them correctly or you need specific mount options not set in content.
  # Often, defining them within the partition 'content' is sufficient.
  # fileSystems."/" = {
  #   device = "/dev/disk/by-label/root";
  #   fsType = "ext4";
  # };
  # fileSystems."/boot" = {
  #   device = "/dev/disk/by-label/ESP";
  #   fsType = "vfat";
  # };
  # swapDevices = [ ... ];
}