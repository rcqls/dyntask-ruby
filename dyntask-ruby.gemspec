require 'rubygems/package_task'

pkg_name='dyntask-ruby'
pkg_version='0.4.1'

pkg_files=FileList[
    'lib/dyntask.rb',
    'lib/dyntask/**/*.rb',
    'share/**/*'
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
    # if RUBY_PLATFORM =~ /mswin|mingw/i
    #   s.add_dependency("win32-dirmonitor","~>1.0.0",">=1.0.1")
    # end
    s.files = pkg_files.to_a
    s.bindir = "bin"
    s.executables = ["dyntask-server","dyntask-init"] ##,"dyntask-reader","dyntask-writer"]
    s.description = <<-EOF
  Managing dyndoc tasks.
  EOF
    s.author = "CQLS"
    s.email= "rdrouilh@gmail.com"
    s.homepage = "http://cqls.upmf-grenoble.fr"
    s.rubyforge_project = nil
end
