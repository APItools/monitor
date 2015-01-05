require 'yaml'

Vagrant.configure('2') do |config|
  config.vm.box = 'ubuntu/trusty64'

  config.vm.provision 'shell', inline: <<-RUBY
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 80F70E11F0F0D5F10CB20E62F5DA5F09C3173AA6
echo 'deb http://ppa.launchpad.net/brightbox/ruby-ng/ubuntu trusty main' > /etc/apt/sources.list.d/ruby-ng.list
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 136221EE520DDFAF0A905689B9316A7BC7917B12
echo 'deb http://ppa.launchpad.net/chris-lea/node.js/ubuntu precise main' > /etc/apt/sources.list.d/nodejs.list
apt-get update && apt-get -y install ruby2.1 bundler git ruby2.1-dev nodejs
gem install bundler
RUBY

  travis = YAML.load_file('.travis.yml')
  env = travis.fetch('env').values.flatten
  env << 'TRAVIS_BUILD_DIR=/vagrant'

  environment = env.map{|env| "echo #{env} >> /etc/environment" }.join("\n")
  config.vm.provision 'shell', inline: environment

  install = ['set -e', env]

  install << travis.fetch('before_install')
  install << travis.fetch('install')

  config.vm.provision 'shell', inline: install.join("\n")
end
