{ pkgs, lib, config, ...}:

{
# Required for nix-darwin to work
	system.stateVersion = 1;

	system.primaryUser = "mahmoodsheikh";

	users.users.mahmooz = {
		name = "mahmooz";
# See the reference docs for more on user config:
# https://nix-darwin.github.io/nix-darwin/manual/#opt-users.users
	};

	environment.systemPackages = with pkgs; [
		neovim
		git
	];

	homebrew = {
		enable = true;
		taps = [
			# for ntfs-3g and macfuse
			"gromgit/homebrew-fuse"
		];
		casks = [
			"emacs"
			"wezterm"
			"firefox"
			"macfuse"
		];
		brews = [
			"imagemagick"
			"ntfs-3g-mac"
			"ext4fuse-mac"
			# "gromgit/fuse/ntfs-3g-mac"
		];
		onActivation.autoUpdate = true;
		onActivation.upgrade = true;
		onActivation.cleanup = "zap";
	};
# Other configuration parameters
# See here: https://nix-darwin.github.io/nix-darwin/manual
}
