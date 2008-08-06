require File.dirname(__FILE__) + '/test_helper'
require 'satellite'

describe 'The homepage' do
  setup do
    @result = request.get('/page/Home')
  end

  it 'should be there' do
    @result.should.be.ok
    @result.should.match '<h2>Home</h2>'
  end
end

describe 'A non-existent wiki page, when navigated to directly' do
  setup do
    @result = request.get('/page/qwertyuiop12345678')
    @final_result = follow @result
  end
  
  it 'should redirect to an edit page' do
    @result.should.redirect_to '/page/qwertyuiop12345678/edit'
    @final_result.should.be.ok
    @final_result.should.match '<h2>Editing qwertyuiop12345678</h2>'
  end
  
  it 'should have a sensible cancellation action' do
    # TODO implement
  end
end

describe 'A non-existent wiki page, when navigated to by a link' do
  setup do
    @referrer = "#{BASE_URI}/page/Home"
    @result = request.get('/page/qwertyuiop12345678', :HTTP_REFERER => @referrer )
    @final_result = follow @result
  end
  
  it 'should redirect back to the referrer upon cancellation' do
    @final_result.should.match '<input type="hidden" name="return_to" value="'+@referrer+'" />'
  end
end

describe 'An existing wiki page, when navigated to directly' do
  setup do
    @res = request.get('/page/Home')
  end
end
