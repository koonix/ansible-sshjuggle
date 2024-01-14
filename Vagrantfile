Vagrant.configure('2') do |config|
  config.vm.box = 'debian/bookworm64'
  config.nfs.functional = false
  config.nfs.verify_installed = false
  config.vm.synced_folder '.', '/vagrant', disabled: true
end
