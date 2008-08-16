require File.dirname(__FILE__) + '/test_helper'
require 'satellite'

describe 'The edit page, when navigated to by a link' do
  setup_and_teardown(:populated)

  before(:each) do
    @referrer = "#{BASE_URI}/page/Home"
    get '/page/Fizz/edit', :HTTP_REFERER => @referrer
  end

  it 'should encode the referrer in a form parameter' do
    should.be.ok
    should.match '<input type="hidden" name="return_to" value="'+@referrer+'" />'
  end
end

