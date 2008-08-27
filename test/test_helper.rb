# add library directories to load path
LIBDIR = File.join(File.expand_path(File.dirname(__FILE__)), '../lib')
$LOAD_PATH.unshift(LIBDIR)
TEST_LIBDIR = File.join(File.expand_path(File.dirname(__FILE__)), 'lib')
$LOAD_PATH.unshift(TEST_LIBDIR)

%w{ configuration satellite rubygems test/spec helper_methods custom_shoulds mock_response_extensions }.each {|l| require l }

#try['mocha', '>= 0.4']

begin require 'redgreen'; rescue LoadError; nil end
