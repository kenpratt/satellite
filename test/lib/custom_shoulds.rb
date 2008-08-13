# camelize methods for custom should lookups
class Symbol
  def camelize
    to_s.camelize
  end
end
class String
  def camelize
    sub(/^(.)/) {|m| $1.upcase }.gsub(/_(.)/) {|m| $1.upcase }
  end
end

# if the other method lookups fail, try looking for a custom should
class Test::Spec::Should
  alias :original_method_missing :method_missing
  def method_missing(name, *args, &block)
    begin
      # try other method lookups first
      original_method_missing(name, *args, &block)
    rescue NoMethodError
      # try to match custom shoulds
      if Satellite::Test::CustomShoulds.const_defined?(name.camelize)
        # custom should found -- give it a call
        pass Satellite::Test::CustomShoulds.const_get(name.camelize).new(*args)
      else
        # no custom should found -- raise a real method missing exception
        super
      end
    end
  end
end

module Satellite
  module Test
    module CustomShoulds
      # for usage on a Rack::MockHttpResponse
      #   should.redirect_to '/path/foo'
      class RedirectTo < ::Test::Spec::CustomShould
        def assumptions(response)
          response.should.be.redirection
          response.headers['Location'].should.equal object
        end
      end
    end
  end
end
