require File.dirname(__FILE__) + '/test_helper'
require 'satellite'

describe 'A wiki, in general,' do
  setup_and_teardown(:populated)

  it 'should have a homepage' do
    get '/page/Home'
    should.be.ok
    should.match '<h2>Home</h2>'
  end

  it 'should redirect / to the homepage' do
    get '/'
    should.redirect_to('/page/Home')
  end
  
  it 'should have an add page' do
    get '/new'
    should.be.ok
    should.match '<h2>Add page</h2>'
  end
  
  it 'should have an edit page' do
    get '/page/Home/edit'
    should.be.ok
    should.match '<h2>Editing Home</h2>'
  end

  it 'should have a list page' do
    get '/list'
    should.be.ok
    should.match '<h2>All pages and uploads</h2>'
  end
  
  it 'should be able to create a new page' do
    post '/new', :input => { :name => 'Freedom', :content => 'Lorem ipsum' }
    should.redirect_to('/page/Freedom')
    
    follow_redirect
    should.be.ok
    should.match '<h2>Freedom</h2>'
    should.match '<p>Lorem ipsum</p>'
  end
  
  it 'should redirect to the edit page for non-existent pages' do
    get '/page/Lolcopter'
    should.redirect_to('/page/Lolcopter/edit')
  end
end

describe 'A totally blank wiki' do
  setup_and_teardown

  it 'should not have an existing homepage' do
    get '/page/Home'
    should.redirect_to('/page/Home/edit')

    follow_redirect
    should.be.ok
    should.match "<h2>Editing Home</h2>"
  end
end
