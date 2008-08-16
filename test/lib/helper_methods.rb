# helper methods available in specs
module Satellite
  module Test
    module HelperMethods
      def new_request
        Rack::MockRequest.new(Satellite.create_server.application)
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
