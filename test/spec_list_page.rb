require File.dirname(__FILE__) + '/test_helper'
require 'satellite'

# Hpricot search paths
def pages; search_body "//div[@id='page-list']/ul/li"; end
def uploads; search_body "//div[@id='upload-list']/ul/li"; end

describe 'A list page for a blank wiki' do
  setup_and_teardown(:empty)

  it 'should have a title' do
    with @ctx do
      get '/list'
      should.be.ok
      should.match '<h2>All pages and uploads</h2>'
    end
  end

  it 'should not have any pages listed' do
    with @ctx do
      get '/list'
      pages.should.be.empty
    end
  end

  it 'should not have any uploads listed' do
    with @ctx do
      get '/list'
      uploads.should.be.empty
    end
  end
end

describe 'A list page for a populated wiki' do
  setup_and_teardown(:populated)

  it 'should have a title' do
    with @ctx do
      get '/list'
      should.be.ok
      should.match '<h2>All pages and uploads</h2>'
    end
  end

  it 'should have some pages listed' do
    with @ctx do
      get '/list'
      pages.size.should.be > 0
    end
  end

  it 'should list pages in (case-insensitive) alphabetical order, with Home first' do
    with @ctx do
      get '/list'
      pages[0].to_s.should.match 'Home'
      pages[1].to_s.should.match 'bazz'
      pages[2].to_s.should.match 'Bozz'
      pages[3].to_s.should.match 'Fizz'
    end
  end

  it 'should have some uploads listed' do
    with @ctx do
      get '/list'
      uploads.size.should.be > 0
    end
  end

  it 'should list uploads in (case-insensitive) alphabetical order' do
    with @ctx do
      get '/list'
      uploads[0].to_s.should.match 'Baaa.txt'
      uploads[1].to_s.should.match 'blam.txt'
      uploads[2].to_s.should.match 'Hello World.txt'
    end
  end
end
