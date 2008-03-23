require 'spec/rake/spectask'

BASE_DIR = File.expand_path(File.dirname(__FILE__))

desc "Clean spec data & Run all specs"
task :spec => [ :clean_spec_data, :all_specs ]

desc "Run all specs"
Spec::Rake::SpecTask.new('all_specs') do |t|
  t.spec_files = FileList[File.join(BASE_DIR, 'spec/**/*.rb')]
  t.spec_opts = ['--options', File.join(BASE_DIR, 'spec/spec.opts')]
  unless ENV['NO_RCOV']
    t.rcov = true
    t.rcov_dir = File.join(BASE_DIR, 'doc/generated/coverage')
    t.rcov_opts = ['--exclude', 'bin,conf,data,doc,spec,static,tmp']
  end
end

desc "Clean spec data"
task :clean_spec_data do
  `rm -rf #{File.join(BASE_DIR, 'doc/generated/coverage')}`
  `rm -rf #{File.join(BASE_DIR, 'tmp/spec*')}`
end
