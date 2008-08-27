# helper methods available in specs
module Satellite
  module Test
    class AppContext
      def initialize(env)
        @env = env
        @server = Server.new(env)
      end

      def container
        c = @server.boot.dependency_container
        c.class_eval do 
          define_method(:base_uri) do
            ip, port = container.conf.server_ip, container.conf.server_port
            'http://' + ip + (port == 80 ? '' : ":#{port}")
          end
        end
        c
      end

      def app
        @server.application.rack_app
      end

      def run
        Dissident.with(container) do |container|
          @context = self
          yield container
        end
      end
    end

    class TestEnv
      inject :conf
      inject :db

      def initialize(state=:blank)
        @state = state
      end

      # tear down any existing stuff and setup test environment
      # assume app context is available
      def setup
        teardown

        # create a master repo for testing
        if !File.exists?(conf.master_repository_uri)
          create_script = File.join(conf.app_dir, 'bin/create_master_repo')
          `#{create_script} #{conf.master_repository_uri}`
        end

        db.sync

        # preload repo?
        if @state == :populated
          Satellite::Models::Page.new('Home', 'I am the Home page.').save
          Satellite::Models::Page.new('Fizz', 'I am the Fizz page.').save
          Satellite::Models::Page.new('Bozz', 'I am the Bozz page.').save
          Satellite::Models::Page.new('bazz', 'I am the bazz page.').save
          Satellite::Models::Upload.new('Hello World.txt').save('Hello World!')
          Satellite::Models::Upload.new('Baaa.txt').save('Meow...')
          Satellite::Models::Upload.new('blam.txt').save('Boom, headshot!')
        end

        db.sync
      end

      # tear down test environment
      def teardown
        db.obliterate!
        FileUtils.cd(conf.app_dir)
        FileUtils.rm_rf(conf.master_repository_uri)
      end
    end

    module HelperMethods
      def new_request
        Rack::MockRequest.new(@context.app)
      end

      def get(uri, opts={})
        @request = new_request
        @response = @request.get(uri, opts)
      end

      def post(uri, opts={})
        @request = new_request

        # stringify input
        if opts[:input]
          opts[:input] = opts[:input].to_a.collect {|k,v| "#{k}=#{Rack::Utils.escape(v)}" }.join('&')
        end

        @response = @request.post(uri, opts)
      end

      def follow_redirect
        @response = @request.get(@response.location)
      end

      # search parsed body using Hpricot
      def search_body(expression)
        @response.parsed_body.search(expression)
      end

      # def fixture(name)
      #   File.dirname(__FILE__) + "/fixtures/#{name}.html"
      # end

      def set_up_test_env(env, state)
        @ctx = Satellite::Test::AppContext.new(env)
        with @ctx do |container|
          @testenv = Satellite::Test::TestEnv.new(state)
          @testenv.setup
          @base_uri = container.base_uri
        end
      end

      def tear_down_test_env
        with @ctx do
          @testenv.teardown
          @testenv = nil
        end
        @ctx = nil
      end
    end
  end
end

# defer to @response.should if no explicit target is defined
class Test::Unit::TestCase
  def should
    @response.should
  end
end

# include helper methods in test cases
Test::Unit::TestCase.send(:include, Satellite::Test::HelperMethods)

# run some test code with a context specified
def with(context, &blk)
  @context = context
  context.run(&blk)
end

# create simple before and after methods
def setup_and_teardown(state)
  before(:each) do
    set_up_test_env(:test, state)
  end
  after(:each) do
    tear_down_test_env
  end
end
