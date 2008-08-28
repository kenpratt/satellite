require File.join(File.expand_path(File.dirname(__FILE__)), 'test_helper')
require 'git_db'

BINDIR = File.join(File.expand_path(File.dirname(__FILE__)), '..', 'bin')
TMPDIR = File.join(File.expand_path(File.dirname(__FILE__)), '..', 'tmp')

class MockLogger
  def method_missing(name, *args)
  end
end

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
  def conf
    c = MockConfig.new
    c.master_repository_uri = File.join(TMPDIR, 'spec_git_db_master_repo')
    c.data_dir = File.join(TMPDIR, 'spec_git_db_data_dir')
    c.user_name = 'Foo Bar'
    c.user_email = 'foo@bar.com'
    c
  end
  def logger; MockLogger.new; end
end

def create_master_repo(path)
  puts "#{File.join(BINDIR, 'create_master_repo')} #{path}"
end

def with_container(&blk)
  Dissident.with(SimpleContainer, &blk)
end

describe 'A new git db' do
  before(:each) do
    with_container do |c|
      create_master_repo(c.conf.master_repository_uri)
      @db = GitDb.new
    end
  end

  after(:each) do
    with_container do |c|
    end
  end

  it 'should work' do
    with_container do
      @db.sync
    end
  end
end
