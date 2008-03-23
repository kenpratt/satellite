$LOAD_PATH.unshift(File.join(File.expand_path(File.dirname(__FILE__)), '../lib'))

require 'satellite'

# load test config
CONF = Configuration.load(:test)

# create a master repo for testing, if it doesn't already exist
if !File.exists?(CONF.master_repository_uri)
  create_script = File.join(CONF.app_dir, 'bin/create_master_repo')
  `#{create_script} #{CONF.master_repository_uri}`
end
