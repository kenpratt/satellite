require 'spec/rake/spectask'

BASE_DIR = File.expand_path(File.dirname(__FILE__))

desc "Run all specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*.rb']
  t.spec_opts = ['--options', 'spec/spec.opts']
  unless ENV['NO_RCOV']
    t.rcov = true
    t.rcov_dir = File.join(BASE_DIR, 'doc/generated/coverage')
    t.rcov_opts = ['--exclude', 'bin,data,doc,spec,static,tmp']
  end
end
