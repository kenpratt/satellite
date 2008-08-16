require File.dirname(__FILE__) + '/test_helper'
require 'satellite'

def return_to; search_body("//input[@name='return_to'").first['value']; end
def cancel_to; search_body("//a[text()='Cancel']").first['href']; end

describe 'The add page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    get '/new'
    should.be.ok
    return_to.should.equal ''
    cancel_to.should.equal '/list'
  end

  it 'should encode the referrer in a form parameter when navigated to by a link' do
    get '/new', "HTTP_REFERER" => "#{BASE_URI}/page/Home"
    should.be.ok
    return_to.should.equal "#{BASE_URI}/page/Home"
    cancel_to.should.equal "#{BASE_URI}/page/Home"
  end

  it 'should encode referrers from different domains too' do
    get '/new', "HTTP_REFERER" => 'http://google.ca/search?foo'
    should.be.ok
    return_to.should.equal 'http://google.ca/search?foo'
    cancel_to.should.equal 'http://google.ca/search?foo'
  end

  it 'should redirect to the show page if no return_to is supplied' do
    post '/new', :input => { :name => 'Frob', :content => '...', :return_to => '' }
    should.redirect_to '/page/Frob'
  end

  it 'should redirect to return_to if return_to is supplied' do
    post '/new', :input => { :name => 'Frib', :content => '...', :return_to => 'http://google.ca/' }
    should.redirect_to 'http://google.ca/'
  end
end

describe 'The edit page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    get '/page/Fizz/edit'
    should.be.ok
    return_to.should.equal ''
    cancel_to.should.equal '/page/Fizz'
  end
  
  it 'should encode the referrer in a form parameter when navigated to by a link' do
    get '/page/Fizz/edit', "HTTP_REFERER" => "#{BASE_URI}/page/Home"
    should.be.ok
    return_to.should.equal "#{BASE_URI}/page/Home"
    cancel_to.should.equal "#{BASE_URI}/page/Home"
  end

  it 'should encode referrers from different domains too' do
    get '/page/Fizz/edit', "HTTP_REFERER" => 'http://google.ca/search?foo'
    should.be.ok
    return_to.should.equal 'http://google.ca/search?foo'
    cancel_to.should.equal 'http://google.ca/search?foo'
  end

  it 'should redirect back to the show page if no return_to is supplied' do
    post '/page/Fizz/edit', :input => { :content => '...', :return_to => '' }
    should.redirect_to '/page/Fizz'
  end
  
  it 'should redirect to return_to if return_to is supplied' do
    post '/page/Fizz/edit', :input => { :content => '...', :return_to => 'http://google.ca/' }
    should.redirect_to 'http://google.ca/'
  end    
end

describe 'The rename page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    get '/page/Fizz/rename'
    should.be.ok
    return_to.should.equal ''
    cancel_to.should.equal '/page/Fizz'
  end
  
  it 'should encode the referrer in a form parameter when navigated to by a link' do
    get '/page/Fizz/rename', "HTTP_REFERER" => "#{BASE_URI}/page/Home"
    should.be.ok
    return_to.should.equal "#{BASE_URI}/page/Home"
    cancel_to.should.equal "#{BASE_URI}/page/Home"
  end

  it 'should encode referrers from different domains too' do
    get '/page/Fizz/rename', "HTTP_REFERER" => 'http://google.ca/search?foo'
    should.be.ok
    return_to.should.equal 'http://google.ca/search?foo'
    cancel_to.should.equal 'http://google.ca/search?foo'
  end

  it 'should redirect to the show page if no return_to is supplied' do
    post '/page/Fizz/rename', :input => { :new_name => 'Fizzz', :return_to => '' }
    should.redirect_to '/page/Fizzz'
  end
  
  it 'should redirect to return_to if return_to is supplied' do
    post '/page/Bozz/rename', :input => { :new_name => 'Bozzz', :return_to => 'http://google.ca/' }
    should.redirect_to 'http://google.ca/'
  end    
end

describe 'The delete page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    get '/page/Fizz/delete'
    should.be.ok
    return_to.should.equal ''
    cancel_to.should.equal '/page/Fizz'
  end
  
  it 'should encode the referrer in a form parameter when navigated to by a link' do
    get '/page/Fizz/delete', "HTTP_REFERER" => "#{BASE_URI}/page/Home"
    should.be.ok
    return_to.should.equal "#{BASE_URI}/page/Home"
    cancel_to.should.equal "#{BASE_URI}/page/Home"
  end

  it 'should encode referrers from different domains too' do
    get '/page/Fizz/delete', "HTTP_REFERER" => 'http://google.ca/search?foo'
    should.be.ok
    return_to.should.equal 'http://google.ca/search?foo'
    cancel_to.should.equal 'http://google.ca/search?foo'
  end

  it 'should redirect to list page if no return_to is supplied' do
    post '/page/Fizz/delete', :input => { :return_to => '' }
    should.redirect_to '/list'
  end
  
  it 'should redirect to return_to if return_to is supplied' do
    post '/page/Bozz/delete', :input => { :return_to => 'http://google.ca/' }
    should.redirect_to 'http://google.ca/'
  end    
end

describe 'The resolve conflict page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    get '/page/Fizz/resolve'
    should.be.ok
    return_to.should.equal ''
    cancel_to.should.equal '/page/Fizz'
  end
  
  it 'should encode the referrer in a form parameter when navigated to by a link' do
    get '/page/Fizz/resolve', "HTTP_REFERER" => "#{BASE_URI}/page/Home"
    should.be.ok
    return_to.should.equal "#{BASE_URI}/page/Home"
    cancel_to.should.equal "#{BASE_URI}/page/Home"
  end

  it 'should encode referrers from different domains too' do
    get '/page/Fizz/resolve', "HTTP_REFERER" => 'http://google.ca/search?foo'
    should.be.ok
    return_to.should.equal 'http://google.ca/search?foo'
    cancel_to.should.equal 'http://google.ca/search?foo'
  end

  it 'should redirect back to the show page if no return_to is supplied' do
    post '/page/Fizz/resolve', :input => { :content => '...', :return_to => '' }
    should.redirect_to '/page/Fizz'
  end
  
  it 'should redirect to return_to if return_to is supplied' do
    post '/page/Fizz/resolve', :input => { :content => '...', :return_to => 'http://google.ca/' }
    should.redirect_to 'http://google.ca/'
  end    
end

describe 'The rename upload page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    get '/upload/blam.txt/rename'
    should.be.ok
    return_to.should.equal ''
    cancel_to.should.equal '/list'
  end
  
  it 'should encode the referrer in a form parameter when navigated to by a link' do
    get '/upload/blam.txt/rename', "HTTP_REFERER" => "#{BASE_URI}/page/Home"
    should.be.ok
    return_to.should.equal "#{BASE_URI}/page/Home"
    cancel_to.should.equal "#{BASE_URI}/page/Home"
  end

  it 'should encode referrers from different domains too' do
    get '/upload/blam.txt/rename', "HTTP_REFERER" => 'http://google.ca/search?foo'
    should.be.ok
    return_to.should.equal 'http://google.ca/search?foo'
    cancel_to.should.equal 'http://google.ca/search?foo'
  end

  it 'should redirect to the show page if no return_to is supplied' do
    post '/upload/blam.txt/rename', :input => { :new_name => 'blzzam.txt', :return_to => '' }
    should.redirect_to '/list'
  end
  
  it 'should redirect to return_to if return_to is supplied' do
    post '/upload/Baaa.txt/rename', :input => { :new_name => 'Rawr.txt', :return_to => 'http://google.ca/' }
    should.redirect_to 'http://google.ca/'
  end    
end

describe 'The delete upload page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    get '/upload/blam.txt/delete'
    should.be.ok
    return_to.should.equal ''
    cancel_to.should.equal '/list'
  end
  
  it 'should encode the referrer in a form parameter when navigated to by a link' do
    get '/upload/blam.txt/delete', "HTTP_REFERER" => "#{BASE_URI}/page/Home"
    should.be.ok
    return_to.should.equal "#{BASE_URI}/page/Home"
    cancel_to.should.equal "#{BASE_URI}/page/Home"
  end

  it 'should encode referrers from different domains too' do
    get '/upload/blam.txt/delete', "HTTP_REFERER" => 'http://google.ca/search?foo'
    should.be.ok
    return_to.should.equal 'http://google.ca/search?foo'
    cancel_to.should.equal 'http://google.ca/search?foo'
  end

  it 'should redirect to list page if no return_to is supplied' do
    post '/upload/blam.txt/delete', :input => { :return_to => '' }
    should.redirect_to '/list'
  end
  
  it 'should redirect to return_to if return_to is supplied' do
    post '/upload/Baaa.txt/delete', :input => { :return_to => 'http://google.ca/' }
    should.redirect_to 'http://google.ca/'
  end    
end
