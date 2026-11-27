{ config, lib, pkgs, ... }:

let
  # partlabel links can appear after disko's udevadm settle, https://github.com/nix-community/disko/issues/739
  waitForDevice = ''udevadm wait --timeout 60 "$device"'';
in
{
  options.vps = {
    disk = lib.mkOption {
      type = lib.types.str;
      default = "/dev/sda";
      description = "disk to wipe (/dev/sda on hetzner, /dev/vda on vultr)";
    };
    swapSize = lib.mkOption {
      type = lib.types.str;
      default = "2G";
    };
  };

  config.disko.devices.disk.main = {
    type = "disk";
    device = config.vps.disk;
    content = {
      type = "gpt";
      partitions = {
        # bios boot partition so the same disk boots on bios and uefi hosts
        boot = lib.mkIf pkgs.stdenv.hostPlatform.isx86 {
          size = "1M";
          type = "EF02";
        };
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            preCreateHook = waitForDevice;
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        swap = {
          size = config.vps.swapSize;
          content = {
            type = "swap";
            preCreateHook = waitForDevice;
            discardPolicy = "both";
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            preCreateHook = waitForDevice;
            mountpoint = "/";
            mountOptions = [ "noatime" ];
          };
        };
      };
    };
  };
}
