require 'spec/rake/spectask'

BASE_DIR = File.expand_path(File.dirname(__FILE__))

desc "Run all specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList[File.join(BASE_DIR, 'spec/**/*.rb')]
  t.spec_opts = ['--options', File.join(BASE_DIR, 'spec/spec.opts')]
  unless ENV['NO_RCOV']
    t.rcov = true
    t.rcov_dir = File.join(BASE_DIR, 'doc/generated/coverage')
    t.rcov_opts = ['--exclude', 'bin,conf,data,doc,spec,static,tmp']
  end
end
