require File.dirname(__FILE__) + '/test_helper'
require 'satellite'

# Hpricot search paths
def pages; @response.parsed_body.search("//div[@id='page-list']/ul/li"); end
def uploads; @response.parsed_body.search("//div[@id='upload-list']/ul/li"); end

describe 'A list page for a blank wiki' do
  setup_and_teardown

  it 'should have a title' do
    get '/list'
    should.be.ok
    should.match '<h2>All pages and uploads</h2>'
  end
  
  it 'should not have any pages listed' do
    get '/list'
    pages.should.be.empty
  end

  it 'should not have any uploads listed' do
    get '/list'
    uploads.should.be.empty
  end
end

describe 'A list page for a populated wiki' do
  setup_and_teardown(:populated)

  it 'should have a title' do
    get '/list'
    should.be.ok
    should.match '<h2>All pages and uploads</h2>'
  end
  
  it 'should have some pages listed' do
    get '/list'
    pages.size.should.be > 0
  end
  
  it 'should list pages in alphabetical order, with Home first' do
    get '/list'
    pages[0].to_s.should.match 'Home'
    pages[1].to_s.should.match 'bazz'
    pages[2].to_s.should.match 'Bozz'
    pages[3].to_s.should.match 'Fizz'
  end
  
  it 'should have some uploads listed' do
    get '/list'
    uploads.size.should.be > 0
  end
  
end
