# helper methods available in specs
module Satellite
  module Test
    module HelperMethods
      def new_request
        Rack::MockRequest.new(Satellite.create_server.application)
      end
  
      def get(*args)
        @request = new_request
        @response = @request.get(*args)
      end
  
      def post(*args)
        @request = new_request
        @response = @request.post(*args)
      end

      def follow_redirect
        @response = @request.get(@response.location)
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
