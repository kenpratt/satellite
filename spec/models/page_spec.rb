require "#{File.expand_path(File.dirname(__FILE__))}/../spec_helper"

module Satellite::Models
  @@i = 0
  
  describe Page, ' when first created (unpersisted)' do
    it 'should have a blank name by default' do
      page = Page.new
      page.name.should_not be_nil
      page.name.should eql('')
    end

    it 'should have the name is was given' do
      page = Page.new('sir page')
      page.name.should eql('sir page')
    end
    
    it 'should not have a directly-modifiable name' do
      page = Page.new('this name is fine')
      lambda { page.name = 'no dice' }.should raise_error(NoMethodError)
    end
    
    it 'should trim whitespace from name' do
      page = Page.new("  \t  \n  poor formatting  \t\r\n  ")
      page.name.should eql('poor formatting')
    end
    
    it 'should not accept an invalid name' do
      lambda { Page.new('//slash//') }.should raise_error(ArgumentError)
    end
    
    it 'should accept a valid name' do
      lambda { Page.new('Aa Zz 09 !@#$%^&()-_+=[]{},.') }.should_not raise_error
    end
    
    it 'should have a blank body by default' do
      page = Page.new
      page.body.should_not be_nil
      page.body.should eql('')
    end
    
    it 'should add a newline to its body if it doesn\'t end with one' do
      page = Page.new('concise', 'hello there')
      page.body.should eql("hello there\n")
    end
    
    it 'should convert CRLF line endings to LF line endings' do
      page = Page.new('heart3crlf', "hello\r\n\r\n  from windows\r\n")
      page.body.should eql("hello\n\n  from windows\n")
    end
    
    it 'should not be able to be renamed before it is saved' do
      page = Page.new('unsaved')
      lambda { page.rename('still_unsaved') }.should raise_error(Db::FileNotFound)
    end

    it 'should be able to be saved' do
      page = Page.new('test_saving')
      lambda { page.save }.should_not raise_error
    end

    it 'should not be able to be saved with blank name' do
      page = Page.new
      lambda { page.save }.should raise_error(ArgumentError)
    end
  end
  
  describe Page, ' when saved' do
    before(:each) do
      @page = Page.new("saved_page_#{@@i += 1}")
      @page.save
    end
    
    it 'should not be able to be renamed to a blank name' do
      lambda { @page.rename('') }.should raise_error(ArgumentError)
    end
    
    it 'should not be able to be renamed to an invalid name' do
      lambda { @page.rename('//slash//') }.should raise_error(ArgumentError)
    end

    it 'should be able to be renamed to a valid name' do
      @page.rename('renamed')
      @page.name.should eql('renamed')
    end
  end
  
  describe Page, ' when formatted' do
    before(:all) do
      @page = Page.new("formatted_page", "_emphasized_\n")
    end
  
    it 'should have a plain version' do
      @page.body.should eql("_emphasized_\n")
    end
  
    it 'should have an html version' do
      @page.body(:html).should eql('<p><em>emphasized</em></p>')
    end
  end
end