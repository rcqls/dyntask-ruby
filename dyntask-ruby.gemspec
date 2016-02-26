require 'rubygems/package_task'

pkg_name='dyntask-ruby'
pkg_version='0.1.1'

pkg_files=FileList[
    'lib/dyntask.rb',
    'lib/dyntask/**/*.rb'
]

spec = Gem::Specification.new do |s|
    s.platform = Gem::Platform::RUBY
    s.summary = "dyntask system"
    s.name = pkg_name
    s.version = pkg_version
    s.licenses = ['MIT', 'GPL-2']
    s.requirements << 'none'
    s.require_path = 'lib'
    s.add_dependency("trollop","~>2.1",">=2.1.2")
    s.add_dependency("filewatcher","~>0.5",">=0.5.2")
    s.files = pkg_files.to_a
    s.bindir = "bin"
    s.executables = ["dyntask-server","dyntask-reader","dyntask-writer","dyntask-init"]
    s.description = <<-EOF
  Managing dyndoc tasks.
  EOF
    s.author = "CQLS"
    s.email= "rdrouilh@gmail.com"
    s.homepage = "http://cqls.upmf-grenoble.fr"
    s.rubyforge_project = nil
end
