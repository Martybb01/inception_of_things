# inception_of_things

Part 1 --> K3s and Vagrant
- setup 2 machines with: latest stable version of OS + 1 CPU + 1024mb RAM
    machine 1: marboccuS (server) with IP 192.168.56.110
    machine 2: marboccuSW (server worker) with IP 192.168.56.111
- connect to them via SSH without password
- Install k3s and kubectl on both --> machine 1 in controller mode, machine 2 in agent mode