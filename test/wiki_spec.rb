require File.dirname(__FILE__) + '/test_helper'
require 'satellite'

describe 'A totally blank wiki' do
  setup_and_teardown

  it 'should redirect / to the homepage' do
    get '/'
    should.redirect_to('/page/Home')
  end

  it 'should not have an existing homepage' do
    get '/page/Home'
    should.redirect_to('/page/Home/edit')

    follow_redirect
    should.be.ok
    should.match "<h2>Editing Home</h2>"
  end
  
  it 'should have an empty list page' do
    get '/list'
    should.be.ok
    should.match '<h2>All pages and uploads</h2>'
    @response.body.should.not.match /<li>/
  end
end

# TODO implement
describe 'A wiki with just a homepage' do
end

describe 'A non-existent wiki page, when navigated to directly' do
  setup_and_teardown
    
  setup do
    get '/page/qwertyuiop12345678'
  end
  
  it 'should redirect to an edit page' do
    should.redirect_to '/page/qwertyuiop12345678/edit'

    follow_redirect
    should.be.ok
    should.match '<h2>Editing qwertyuiop12345678</h2>'
  end
  
  # TODO implement
  it 'should have a sensible cancellation action' do
  end
end

describe 'A non-existent wiki page, when navigated to by a link' do
  setup_and_teardown

  setup do
    @referrer = "#{BASE_URI}/page/Home"
    get '/page/qwertyuiop12345678', :HTTP_REFERER => @referrer
  end
  
  # TODO enable
  xit 'should redirect back to the referrer upon cancellation' do
    should.redirect_to '/page/qwertyuiop12345678/edit'
    
    follow_redirect
    should.match '<input type="hidden" name="return_to" value="'+@referrer+'" />'
  end
end
