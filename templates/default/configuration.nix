# Example Steam Link system: what `nix flake init -t github:slopmaxxer/nixos-steamlink`
# starts from, and what CI builds. Without an SSH key nobody can log in; add yours.
{ ... }:
{
  networking.hostName = "steamlink";

  # Ethernet via DHCP; `ssh root@steamlink.local` through mDNS.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    # "ssh-ed25519 AAAA... you@example"
  ];

  system.stateVersion = "26.11";
}
