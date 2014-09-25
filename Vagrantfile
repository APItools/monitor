# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = '2'

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = '3scale/docker'
  config.vm.box_version = '>= 0.10.0.2'

#  ip = '10.17.42.2'
#  # https://www.virtualbox.org/manual/ch06.html#network_internal
#  # network just between host and vms
#  config.vm.network :private_network, ip: ip, netmask: '255.255.0.0'

#  config.vm.provision :shell, inline: <<-docker
#    echo 'DOCKER_OPTS="-H tcp://0.0.0.0:4243 -H unix:// -bip=#{ip}/16"' > /etc/default/docker
#  docker

#  config.vm.provision :shell, inline: <<-network
#    echo "#!/bin/sh -e" > /etc/rc.local
#    echo ip addr del #{ip}/16 dev eth1 >> /etc/rc.local
#    echo ip link set eth1 master docker0 >> /etc/rc.local
#    echo service docker restart >> /etc/rc.local
#    chmod +x /etc/rc.local 2> /dev/null
#  network
#
#  config.vm.provision :shell, inline: '/etc/rc.local'
end
