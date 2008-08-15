require 'hpricot'

class Rack::MockResponse
  # for better matching
  def parsed_body
    Hpricot(body)
  end
end
