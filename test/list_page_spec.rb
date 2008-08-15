require File.dirname(__FILE__) + '/test_helper'
require 'satellite'

describe 'A list page for a blank wiki' do
  setup_and_teardown

  it 'should have a title' do
    get '/list'
    should.be.ok
    should.match '<h2>All pages and uploads</h2>'
  end
  
  it 'should not have any pages or uploads listed' do
    get '/list'
    should.be.ok
    @response.body.should.not.match /<li>/
  end
end

describe 'A list page for a populated wiki' do
  setup_and_teardown(:populated)

  it 'should have some pages listed' do
    get '/list'
    should.be.ok
    @response.body.should.match /<li>/
  end
end
