# variables that need to be set per machine
{}: rec {
  remote_tunnel_port = 5001; # the port to open for the machine on the main server (for tunneling)
  enable_nvidia = false;
  machine_name = "mahmooz1";
  is_desktop = true;
  static_ip = if machine_name == "mahmooz1" then "192.168.1.1"
              else if machine_name == "mahmooz2" then "192.168.1.2"
              else "192.168.1.100";
}