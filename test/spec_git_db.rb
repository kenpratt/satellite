require File.dirname(__FILE__) + '/test_helper'
require 'git_db'

class MockConfig
  def values
    @values ||= {}
  end

  def set(opt, val)
    values.store(opt, val)
  end

  def method_missing(name, *args)
    if values.has_key?(name)
      values[name]
    elsif name.to_s =~ /^([\s\S]+)=$/
      values.store($1.to_sym, *args)
    else
      raise ArgumentError.new("Need to provide a value for #{name}")
    end
  end
end

class SimpleContainer < Dissident::Container
  def conf; MockConfig.new; end
end

def with_container(&blk)
  Dissident.with(SimpleContainer, &blk)
end

describe 'A new git db' do
  before(:each) do
    with_container do |c|
      c.conf.master_repository_uri = 'sd'
      @db = GitDb.new
    end
  end

  after(:each) do
    with_container do |c|
    end
  end

  it 'should work' do
    @db.sync
  end
end
