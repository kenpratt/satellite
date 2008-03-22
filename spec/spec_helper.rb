%w{ config lib }.each {|l| $LOAD_PATH.unshift("#{File.expand_path(File.dirname(__FILE__))}/../#{l}") }

# make config changes for spec environment
require 'config'

SPEC_DATA_DIR = File.join(Conf::APP_DIR, 'tmp/spec_data')
SPEC_MASTER_REPO = File.join(Conf::APP_DIR, 'tmp/spec_master_repo')

# override data dir, so we don't overwrite app data
Conf::DATA_DIR = SPEC_DATA_DIR

# override app repo, so we don't commit to production
Conf::ORIGIN_URI = SPEC_MASTER_REPO

if !File.exists?(SPEC_MASTER_REPO)
  create_script = File.join(Conf::APP_DIR, 'bin/create_master_repo')
  `#{create_script} #{Conf::ORIGIN_URI}`
end

# now that config changes have been made, require satellite
require 'satellite'
