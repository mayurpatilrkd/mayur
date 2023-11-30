#!/bin/bash

# Function to perform tasks on a target machine
configure_target() {
  local target_ip=$1
  local hostname=$2

  # Change system name
  ssh remoteadmin@$target_ip "sudo hostnamectl set-hostname $hostname"
  ssh remoteadmin@$target_ip "sudo sed -i 's/^127.0.1.1.*/127.0.1.1\t$hostname/g' /etc/hosts"

  # Change IP address on the LAN
  ssh remoteadmin@$target_ip "sudo ip addr del 172.16.1.$((10#$hostname)) dev eth0 && \
                              sudo ip addr add 172.16.1.$((10#$hostname)) dev eth0"

  # Add a machine named webhost to /etc/hosts
  ssh remoteadmin@$target_ip "echo '172.16.1.4 webhost' | sudo tee -a /etc/hosts"

  # Install ufw if necessary and allow connections to port 514/udp from the mgmt network
  ssh remoteadmin@$target_ip "sudo apt-get update && \
                              sudo apt-get install -y ufw && \
                              sudo ufw allow from 172.16.1.0/24 to any port 514/udp && \
                              sudo ufw --force enable"

  # Configure rsyslog to listen for UDP connections
  ssh remoteadmin@$target_ip "sudo sed -i '/^#module(imudp)/s/^#//; /^#input(imudp/s/^#//; /^#imudp/s/^#//' /etc/rsyslog.conf && \
                              sudo systemctl restart rsyslog"
}

# Configure target1
configure_target 172.16.1.10 loghost

# Configure target2
configure_target 172.16.1.11 webhost

# Update NMS /etc/hosts file
echo "172.16.1.10 loghost" | sudo tee -a /etc/hosts
echo "172.16.1.11 webhost" | sudo tee -a /etc/hosts

# Verify Apache response on NMS
if firefox http://webhost; then
  echo "Configuration update succeeded. Apache responded properly."
else
  echo "Configuration update failed. Unable to retrieve Apache response."
fi

# Verify syslog entries on loghost
if ssh remoteadmin@loghost grep webhost /var/log/syslog; then
  echo "Syslog entries show logs from webhost."
else
  echo "Syslog entries do not show logs from webhost."
fi
