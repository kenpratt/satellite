require 'spec/rake/spectask'

desc "Run all specs"
Spec::Rake::SpecTask.new do |t|
  t.spec_files = FileList['spec/**/*.rb']
  t.spec_opts = ['--options', 'spec/spec.opts']
  unless ENV['NO_RCOV']
    t.rcov = true
    t.rcov_dir = 'doc/output/coverage'
    t.rcov_opts = ['--exclude', 'bin,content,spec,spec_content,spec_repo,static']
  end
end
