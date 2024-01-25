Vagrant.configure('2') do |config|
  config.vm.define "vm1"
  config.vm.define "vm2"
  config.vm.box = 'debian/bookworm64'
  config.nfs.functional = false
  config.nfs.verify_installed = false
  config.vm.synced_folder '.', '/vagrant', disabled: true
  config.vm.provider 'libvirt' do |libvirt|
    if File.exist?('/dev/kvm')
      libvirt.driver = 'kvm'
    else
      libvirt.driver = 'qemu'
    end
  end
end
