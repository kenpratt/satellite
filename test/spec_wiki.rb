require File.dirname(__FILE__) + '/test_helper'
require 'satellite'

describe 'A wiki, in general,' do
  setup_and_teardown(:populated)

  it 'should have a homepage' do
    with @ctx do
      get '/page/Home'
      should.be.ok
      should.match '<h2>Home</h2>'
    end
  end

  it 'should redirect / to the homepage' do
    with @ctx do
      get '/'
      should.redirect_to('/page/Home')
    end
  end

  it 'should have an add page' do
    with @ctx do
      get '/new'
      should.be.ok
      should.match '<h2>Add page</h2>'
    end
  end

  it 'should have an edit page' do
    with @ctx do
      get '/page/Home/edit'
      should.be.ok
      should.match '<h2>Editing Home</h2>'
    end
  end

  it 'should have a list page' do
    with @ctx do
      get '/list'
      should.be.ok
      should.match '<h2>All pages and uploads</h2>'
    end
  end

  it 'should be able to create a new page' do
    with @ctx do
      post '/new', :input => { :name => 'Freedom', :content => 'Lorem ipsum' }
      should.redirect_to('/page/Freedom')

      follow_redirect
      should.be.ok
      should.match '<h2>Freedom</h2>'
      should.match '<p>Lorem ipsum</p>'
    end
  end

  it 'should redirect to the edit page for non-existent pages' do
    with @ctx do
      get '/page/Lolcopter'
      should.redirect_to('/page/Lolcopter/edit')
    end
  end

  it 'should have a pretty 404 page' do
    with @ctx do
      get '/four-oh-four'
      @response.status.should.be.equal 404
      should.match '<h2>404, Baby</h2>'
    end
  end
end

describe 'A totally blank wiki' do
  setup_and_teardown(:blank)

  it 'should not have an existing homepage' do
    with @ctx do
      get '/page/Home'
      should.redirect_to('/page/Home/edit')

      follow_redirect
      should.be.ok
      should.match "<h2>Editing Home</h2>"
    end
  end
end
