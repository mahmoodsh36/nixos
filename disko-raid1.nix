# echo -n "your-password" > /tmp/secret.key
# sudo disko --mode destroy,format,mount ./disko-raid1.nix
{
  disko.devices = {
    disk = {
      disk1 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST18000NM000J-2TV103_WR50CE23";
        content = {
          type = "gpt";
          partitions = {
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted1";
                # file containing the password to use for encryption during installation.
                # you must create this file on the target machine before running nixos-anywhere.
                passwordFile = "/tmp/secret.key";
                # prevent asking for password at boot (for remote servers)
                initrdUnlock = false;
                settings = {
                  allowDiscards = true;
                  # keyFile = "/tmp/secret.key"; # commented out to enable interactive password entry at boot
                };
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" ]; # override existing partition
                  subvolumes = {
                    "/data" = {
                      mountpoint = "/data";
                      # nofail: don't hang boot if drive is missing/locked
                      # noauto: don't mount automatically at boot (wait for manual unlock)
                      mountOptions = [ "compress=zstd" "noatime" "nofail" "noauto" ];
                    };
                  };
                };
              };
            };
          };
        };
      };
      disk2 = {
        type = "disk";
        device = "/dev/disk/by-id/ata-ST18000NM000J-2TV103_WR50H9LF";
        content = {
          type = "gpt";
          partitions = {
            luks = {
              size = "100%";
              content = {
                type = "luks";
                name = "crypted2";
                passwordFile = "/tmp/secret.key";
                initrdUnlock = false;
                settings = {
                  allowDiscards = true;
                };
                content = {
                  type = "btrfs";
                  extraArgs = [ "-f" "-d" "raid1" "/dev/mapper/crypted1" ];
                  # subvolumes are already defined on the filesystem created on disk1 (which this joins)
                  # so we don't need to redefine them here.
                };
              };
            };
          };
        };
      };
    };
  };
}