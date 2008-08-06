$:.unshift 'lib/', File.dirname(__FILE__) + '/../lib'

require 'rubygems'

try = proc do |library, version|
  begin
    dashed = library.gsub('/','-')
    require library
    gem dashed, version
  rescue LoadError
    puts "=> You need the #{library} gem to run these tests.",
         "=> $ sudo gem install #{dashed}"
    exit
  end
end

try['test/spec', '>= 0.3']
#try['mocha', '>= 0.4']

begin require 'redgreen'; rescue LoadError; nil end

require 'configuration'
require 'satellite'

CONF = Configuration.load(:test)

BASE_URI = 'http://' + CONF.server_ip + (CONF.server_port != 80 ? ":#{CONF.server_port}" : '')

def fixture(name)
  File.dirname(__FILE__) + "/fixtures/#{name}.html"
end

def request
  @request = Rack::MockRequest.new(Satellite.server.application)
end

def follow(response)
  @request.get(response.location)
end
