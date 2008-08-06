require File.dirname(__FILE__) + '/test_helper'
require 'satellite'

describe 'The homepage' do
  setup do
    @res = request.get('/page/Home')
  end

  it 'should be there' do
   @res.should.be.ok
   @res.should.match /<h2>Home<\/h2>/
 end
end
