require File.dirname(__FILE__) + '/test_helper'
require 'satellite'

describe 'Two wikis with the same master repository' do
  before(:each) do
    @ctx1 = Satellite::Test::AppContext.new(:test)
     with @ctx1 do |container|
      @testenv1 = Satellite::Test::TestEnv.new(:populated)
      @testenv1.setup
      @base_uri1 = container.base_uri
    end

    @ctx2 = Satellite::Test::AppContext.new(:test_same_master)
    with @ctx2 do |container|
      @testenv2 = Satellite::Test::TestEnv.new(:populated)
      @testenv2.setup
      @base_uri2 = container.base_uri
    end
  end

  after(:each) do
    @ctx1.run { @testenv1.teardown }
    @ctx2.run { @testenv2.teardown }
  end

  it 'should have two wikis' do
    with @ctx1 do
      get '/page/Home'
      should.be.ok
      should.match '<h2>Home</h2>'
    end
    with @ctx2 do
      get '/page/Home'
      should.be.ok
      should.match '<h2>Home</h2>'
    end
  end

  it 'should be able to create a conflict' do
    with @ctx1 do |container|
      lambda { container.db.sync }.should.not.raise
    end
    with @ctx2 do |container|
      lambda { container.db.sync }.should.not.raise
    end

    # edit on wiki 1
    with @ctx1 do
      post '/page/Fizz', :input => { :content => "I am the Fizz page.\n\nOr am I?" }
      follow_redirect
      should.be.ok
      should.match '<h2>Fizz</h2>'
      should.match "<p>I am the Fizz page.</p>\n<p>Or am I?</p>"
    end

    # edit on wiki 2
    with @ctx2 do
      post '/page/Fizz', :input => { :content => "I am *not* the Fizz page." }
      follow_redirect
      should.be.ok
      should.match '<h2>Fizz</h2>'
      should.match '<p>I am <strong>not</strong> the Fizz page.</p>'
    end

    # push change 1
    with @ctx1 do |container|
      lambda { container.db.sync }.should.not.raise
    end

    # push change 2
    with @ctx2 do |container|
      lambda { container.db.sync }.should.raise GitDb::MergeConflict
    end
  end
end
