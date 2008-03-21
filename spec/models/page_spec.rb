require "#{File.expand_path(File.dirname(__FILE__))}/../spec_helper"

module Satellite::Models
  describe Page, ' when first created' do
    it 'should have a blank name by default' do
      page = Page.new
      page.name.should_not be_nil
      page.name.should eql('')
    end

    it 'should have the name is was given' do
      page = Page.new('foobar')
      page.name.should eql('foobar')
    end
    
    it 'should not have a directly-modifiable name' do
      page = Page.new
      lambda { page.name = 'boobear' }.should raise_error(NoMethodError)
    end
    
    it 'should trim whitespace from name' do
      page = Page.new("  \t  \n  foo  \t\r\n  ")
      page.name.should eql('foo')
    end
    
    it 'should not accept an invalid name' do
      lambda { Page.new('////') }.should raise_error(ArgumentError)
    end
    
    it 'should accept a valid name' do
      lambda { Page.new('Aa Zz 09 !@#$%^&()-_+=[]{},.') }.should_not raise_error
    end
    
    it 'should have a blank body by default' do
      page = Page.new
      page.body.should_not be_nil
      page.body.should eql('')
    end
    
    it 'should add newline to body' do
      page = Page.new('foo', 'hello there')
      page.body.should eql("hello there\n")
    end
    
    it 'should convert CRLF line endings to LF' do
      page = Page.new('foo', "hello\r\n\r\n  there\r\n")
      page.body.should eql("hello\n\n  there\n")
    end
    
    it 'should have html version of body' do
      page = Page.new('foo', "_emphasized_")
      page.body(:html).should eql('<p><em>emphasized</em></p>')
    end
  end
  
  describe Page, ' when saved' do
    it 'should be able to be saved' do
      page = Page.new('test_saving')
      lambda { page.save }.should_not raise_error
    end
    
    it 'should not be able to be saved with blank name' do
      page = Page.new
      lambda { page.save }.should raise_error(ArgumentError)
    end
  end
  
  describe Page, ' when renamed' do
    it 'should not be able to rename an unsaved page' do
      page = Page.new('unsaved')
      lambda { page.rename('still_unsaved') }.should raise_error(Db::FileNotFound)
      end
    
    it 'should not be able to be renamed to a blank name' do
      page = Page.new('test_rename')
      lambda { page.rename('') }.should raise_error(ArgumentError)
    end
    
    it 'should not be able to be renamed to an invalid name' do
      page = Page.new('test_rename')
      lambda { page.rename('////') }.should raise_error(ArgumentError)
    end

    # it 'should be able to be renamed to a valid name' do
    #   page = Page.new('test_rename')
    #   page.save
    #   page.rename('renamed')
    # end
  end
end