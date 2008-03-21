%w{ config lib }.each {|l| $LOAD_PATH.unshift("#{File.expand_path(File.dirname(__FILE__))}/../#{l}") }

require 'satellite'

SPEC_DATA_DIR = 'spec_content'
SPEC_MASTER_REPO = 'spec_repo'

# override data dir, so we don't overwrite app data
Conf::DATA_DIR = File.join(Conf::APP_DIR, SPEC_DATA_DIR)

# override app repo, so we don't commit to production
Conf::ORIGIN_URI = File.join(Conf::APP_DIR, SPEC_MASTER_REPO)

if !File.exists?(SPEC_MASTER_REPO)
  create_script = File.join(Conf::APP_DIR, 'bin/create_master_repo')
  `#{create_script} #{Conf::ORIGIN_URI}`
end
