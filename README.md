# Quick & Easy OpenVPN

This is a quick and easy OpenVPN installation for Ubuntu or Debian systems. Download/clone, run, and you'll have a VPN. This was tested on Ubuntu 19.

# Usage

1) Clone the repo at `https://github.com/Novabutter/Quick-Easy-OpenVPN.git`, or download `vpn-install.sh`.
2) Change the permissions on the file to be execute via the command `chmod 700 vpn-install.sh`. 
3) Run the file as a non-root user for security reasons. You'll be asked what your super user password is as the script runs. Do this with `./vpn-install.sh`.
4) You should have a client config spawn once this is finished. Don't forget to port-forward if necessary. 

# Warning

This script is decently volatile at the moment. It has major potential to fail in its current state, but so long as you follow the instructions clearly it should be fine.  
