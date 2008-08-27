require File.dirname(__FILE__) + '/test_helper'
require 'satellite'

def return_to; search_body("//input[@name='return_to'").first['value']; end
def cancel_to; search_body("//a[text()='Cancel']").first['href']; end

describe 'The add page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    with @ctx do
      get '/new'
      should.be.ok
      cancel_to.should.equal '/list'
    end
  end

  it 'should encode the referrer in a form parameter when navigated to by a link' do
    with @ctx do
      get '/new', "HTTP_REFERER" => "#{@base_uri}/page/Home"
      should.be.ok
      cancel_to.should.equal "#{@base_uri}/page/Home"
    end
  end

  it 'should encode referrers from different domains too' do
    with @ctx do
      get '/new', "HTTP_REFERER" => 'http://google.ca/search?foo'
      should.be.ok
      cancel_to.should.equal 'http://google.ca/search?foo'
    end
  end

  it 'should redirect to the show page if no return_to is supplied' do
    with @ctx do
      post '/new', :input => { :name => 'Frob', :content => '...', :return_to => '' }
      should.redirect_to '/page/Frob'
    end
  end

  it 'should redirect to the show page when saved and ignore return_to' do
    with @ctx do
      post '/new', :input => { :name => 'frimm', :content => '...', :return_to => "#{@base_uri}/list" }
      should.redirect_to '/page/frimm'
    end
  end
end

describe 'The edit page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    with @ctx do
      get '/page/Fizz/edit'
      should.be.ok
      return_to.should.equal ''
      cancel_to.should.equal '/page/Fizz'
    end
  end

  it 'should encode the referrer in a form parameter when navigated to by a link' do
    with @ctx do
      get '/page/Fizz/edit', "HTTP_REFERER" => "#{@base_uri}/page/Home"
      should.be.ok
      return_to.should.equal "#{@base_uri}/page/Home"
      cancel_to.should.equal "#{@base_uri}/page/Home"
    end
  end

  it 'should encode referrers from different domains too' do
    with @ctx do
      get '/page/Fizz/edit', "HTTP_REFERER" => 'http://google.ca/search?foo'
      should.be.ok
      return_to.should.equal 'http://google.ca/search?foo'
      cancel_to.should.equal 'http://google.ca/search?foo'
    end
  end

  it 'should redirect back to the show page if no return_to is supplied' do
    with @ctx do
      post '/page/Fizz/edit', :input => { :content => '...', :return_to => '' }
      should.redirect_to '/page/Fizz'
    end
  end

  it 'should redirect to return_to if return_to is supplied' do
    with @ctx do
      post '/page/Fizz/edit', :input => { :content => '...', :return_to => 'http://google.ca/' }
      should.redirect_to 'http://google.ca/'
    end
  end
end

describe 'The rename page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    with @ctx do
      get '/page/Fizz/rename'
      should.be.ok
      return_to.should.equal ''
      cancel_to.should.equal '/page/Fizz'
    end
  end

  it 'should encode the referrer in a form parameter when navigated to by a link' do
    with @ctx do
      get '/page/Fizz/rename', "HTTP_REFERER" => "#{@base_uri}/page/Home"
      should.be.ok
      return_to.should.equal "#{@base_uri}/page/Home"
      cancel_to.should.equal "#{@base_uri}/page/Home"
    end
  end

  it 'should encode referrers from different domains too' do
    with @ctx do
      get '/page/Fizz/rename', "HTTP_REFERER" => 'http://google.ca/search?foo'
      should.be.ok
      return_to.should.equal 'http://google.ca/search?foo'
      cancel_to.should.equal 'http://google.ca/search?foo'
    end
  end

  it 'should redirect to the show page if no return_to is supplied' do
    with @ctx do
      post '/page/Fizz/rename', :input => { :new_name => 'Fizzz', :return_to => '' }
      should.redirect_to '/page/Fizzz'
    end
  end

  it 'should redirect to return_to if return_to is supplied' do
    with @ctx do
      post '/page/Bozz/rename', :input => { :new_name => 'Bozzz', :return_to => 'http://google.ca/' }
      should.redirect_to 'http://google.ca/'
    end
  end

  it 'should return to the new show page if return_to is the old show page' do
    with @ctx do
      post '/page/bazz/rename', :input => { :new_name => 'bazzz', :return_to => "#{@base_uri}/page/bazz" }
      should.redirect_to '/page/bazzz'
    end
  end
end

describe 'The delete page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    with @ctx do
      get '/page/Fizz/delete'
      should.be.ok
      return_to.should.equal ''
      cancel_to.should.equal '/page/Fizz'
    end
  end

  it 'should encode the referrer in a form parameter when navigated to by a link' do
    with @ctx do
      get '/page/Fizz/delete', "HTTP_REFERER" => "#{@base_uri}/page/Home"
      should.be.ok
      return_to.should.equal "#{@base_uri}/page/Home"
      cancel_to.should.equal "#{@base_uri}/page/Home"
    end
  end

  it 'should encode referrers from different domains too' do
    with @ctx do
      get '/page/Fizz/delete', "HTTP_REFERER" => 'http://google.ca/search?foo'
      should.be.ok
      return_to.should.equal 'http://google.ca/search?foo'
      cancel_to.should.equal 'http://google.ca/search?foo'
    end
  end

  it 'should redirect to list page if no return_to is supplied' do
    with @ctx do
      post '/page/Fizz/delete', :input => { :return_to => '' }
      should.redirect_to '/list'
    end
  end

  it 'should redirect to return_to if return_to is supplied' do
    with @ctx do
      post '/page/Bozz/delete', :input => { :return_to => 'http://google.ca/' }
      should.redirect_to 'http://google.ca/'
    end
  end

  it 'should return to the list page if return_to is the show page for the deleted page' do
    with @ctx do
      post '/page/bazz/delete', :input => { :return_to => "#{@base_uri}/page/bazz" }
      should.redirect_to '/list'
    end
  end
end

describe 'The resolve conflict page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    with @ctx do
      get '/page/Fizz/resolve'
      should.be.ok
      return_to.should.equal ''
      cancel_to.should.equal '/page/Fizz'
    end
  end

  it 'should encode the referrer in a form parameter when navigated to by a link' do
    with @ctx do
      get '/page/Fizz/resolve', "HTTP_REFERER" => "#{@base_uri}/page/Home"
      should.be.ok
      return_to.should.equal "#{@base_uri}/page/Home"
      cancel_to.should.equal "#{@base_uri}/page/Home"
    end
  end

  it 'should encode referrers from different domains too' do
    with @ctx do
      get '/page/Fizz/resolve', "HTTP_REFERER" => 'http://google.ca/search?foo'
      should.be.ok
      return_to.should.equal 'http://google.ca/search?foo'
      cancel_to.should.equal 'http://google.ca/search?foo'
    end
  end

  it 'should redirect back to the show page if no return_to is supplied' do
    with @ctx do
      post '/page/Fizz/resolve', :input => { :content => '...', :return_to => '' }
      should.redirect_to '/page/Fizz'
    end
  end

  it 'should redirect to return_to if return_to is supplied' do
    with @ctx do
      post '/page/Fizz/resolve', :input => { :content => '...', :return_to => 'http://google.ca/' }
      should.redirect_to 'http://google.ca/'
    end
  end
end

describe 'The rename upload page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    with @ctx do
      get '/upload/blam.txt/rename'
      should.be.ok
      return_to.should.equal ''
      cancel_to.should.equal '/list'
    end
  end

  it 'should encode the referrer in a form parameter when navigated to by a link' do
    with @ctx do
      get '/upload/blam.txt/rename', "HTTP_REFERER" => "#{@base_uri}/page/Home"
      should.be.ok
      return_to.should.equal "#{@base_uri}/page/Home"
      cancel_to.should.equal "#{@base_uri}/page/Home"
    end
  end

  it 'should encode referrers from different domains too' do
    with @ctx do
      get '/upload/blam.txt/rename', "HTTP_REFERER" => 'http://google.ca/search?foo'
      should.be.ok
      return_to.should.equal 'http://google.ca/search?foo'
      cancel_to.should.equal 'http://google.ca/search?foo'
    end
  end

  it 'should redirect to the show page if no return_to is supplied' do
    with @ctx do
      post '/upload/blam.txt/rename', :input => { :new_name => 'blzzam.txt', :return_to => '' }
      should.redirect_to '/list'
    end
  end

  it 'should redirect to return_to if return_to is supplied' do
    with @ctx do
      post '/upload/Baaa.txt/rename', :input => { :new_name => 'Rawr.txt', :return_to => 'http://google.ca/' }
      should.redirect_to 'http://google.ca/'
    end
  end
end

describe 'The delete upload page' do
  setup_and_teardown(:populated)

  it 'should not encode the referrer when navigated to directly' do
    with @ctx do
      get '/upload/blam.txt/delete'
      should.be.ok
      return_to.should.equal ''
      cancel_to.should.equal '/list'
    end
  end

  it 'should encode the referrer in a form parameter when navigated to by a link' do
    with @ctx do
      get '/upload/blam.txt/delete', "HTTP_REFERER" => "#{@base_uri}/page/Home"
      should.be.ok
      return_to.should.equal "#{@base_uri}/page/Home"
      cancel_to.should.equal "#{@base_uri}/page/Home"
    end
  end

  it 'should encode referrers from different domains too' do
    with @ctx do
      get '/upload/blam.txt/delete', "HTTP_REFERER" => 'http://google.ca/search?foo'
      should.be.ok
      return_to.should.equal 'http://google.ca/search?foo'
      cancel_to.should.equal 'http://google.ca/search?foo'
    end
  end

  it 'should redirect to list page if no return_to is supplied' do
    with @ctx do
      post '/upload/blam.txt/delete', :input => { :return_to => '' }
      should.redirect_to '/list'
    end
  end

  it 'should redirect to return_to if return_to is supplied' do
    with @ctx do
      post '/upload/Baaa.txt/delete', :input => { :return_to => 'http://google.ca/' }
      should.redirect_to 'http://google.ca/'
    end
  end
end
