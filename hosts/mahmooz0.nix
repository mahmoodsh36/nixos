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
		brews = [
			"imagemagick"
		];
		casks = [
			"emacs"
			"wezterm"
			"firefox"
		];
	};
# Other configuration parameters
# See here: https://nix-darwin.github.io/nix-darwin/manual
}
