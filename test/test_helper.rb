# add library directories to load path
LIBDIR = File.join(File.expand_path(File.dirname(__FILE__)), '../lib')
$LOAD_PATH.unshift(LIBDIR)
TEST_LIBDIR = File.join(File.expand_path(File.dirname(__FILE__)), 'lib')
$LOAD_PATH.unshift(TEST_LIBDIR)

%w{ configuration satellite rubygems test/spec helper_methods custom_shoulds }.each {|l| require l }

#try['mocha', '>= 0.4']

begin require 'redgreen'; rescue LoadError; nil end

CONF = Configuration.load(:test)
BASE_URI = 'http://' + CONF.server_ip + (CONF.server_port != 80 ? ":#{CONF.server_port}" : '')

def fixture(name)
  File.dirname(__FILE__) + "/fixtures/#{name}.html"
end

# tear down any existing stuff and setup test environment
def setup_repository
  teardown_repository
  
  # create a master repo for testing
  if !File.exists?(CONF.master_repository_uri)
    create_script = File.join(CONF.app_dir, 'bin/create_master_repo')
    `#{create_script} #{CONF.master_repository_uri}`
  end
end

# tear down test environment
def teardown_repository
  GitDb.obliterate!
  FileUtils.cd(CONF.app_dir)
  FileUtils.rm_rf(CONF.master_repository_uri)
end

def setup_and_teardown
  before(:all) { setup_repository }
  after(:all) { teardown_repository }
end
