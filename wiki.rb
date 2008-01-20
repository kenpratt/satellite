#!/bin/env ruby

%w{ rubygems mongrel metaid redcloth open-uri erubis }.each {|gem| require gem }

# TODO integtrate configuration into app definition so framework doesn't rely on these constants
APPNAME = 'Wiki'
ADDR, PORT = '0.0.0.0', 3000

require 'framework'

class Page
  VALID_NAME_CHARS = '\w \!\@\#\$\%\^\&\(\)\-\_\+\=\[\]\{\}\,\.'
  
  attr_reader :name
  attr_writer :body
  
  def initialize(name='', body='')
    @name = name
    @body = body
    raise ArgumentError.new("name is invalid: #{name}") if name.any? && !valid_name?
  end
  
  def self.list
    Dir[filename('*')].collect {|s| s.sub(/^content\/(.+)\.textile$/, '\1') }.sort.collect {|s| Page.new(s) }
  end
  
  def self.load(name)
    if exists?(name)
      Page.new(name, open(filename(name)).read)
    else
      nil
    end
  end

  def self.exists?(name)
    File.exists?(filename(name))
  end
  
  def self.filename(name)
    "content/#{name}.textile"
  end
  
  def filename
    Page.filename(name)
  end
  
  def body(format=nil)
    case format
    when :html
      RedCloth.new(@body).to_html
    else
      @body
    end
  end
  
  def save
    save_file(@body, filename)
  end
  
  def valid_name?
    name =~ /^[#{VALID_NAME_CHARS}]+$/
  end
end


class WikiController < RequestHandler
  VALID_CHARS = '\w \+\%\-\.'
  NAME = "([#{VALID_CHARS}]+)"
  
  alias :original_render :render
  def render(template, title, params={})
    original_render(template, params.merge!({ :title => title, :uri => Uri }))
  end
  
  class Uri
    class << self
      def page(name) "/page/#{RequestHandler.escape(name)}" end
      def edit_page(name) "/page/#{RequestHandler.escape(name)}/edit" end
      def new_page() '/new' end
      def list() '/list' end
      def home() '/page/Home' end
    end
  end
end

# TODO it would be nice to have this be like camping, with something like < R "/page/(.+)"
# instead of the inherit block. the necessary method might look like:
#
# see: http://whytheluckystiff.net/articles/seeingMetaclassesClearly.html
# def R(uri_format)
#   Class.new(RequestHandler) do
#     meta_def(:uri_format) { uri_format }
#   end
# end
#
class PageController < WikiController
  def initialize
    super "/page/#{NAME}", "/page/#{NAME}/(edit)"
  end
  
  def get(name, action='view')
    page = Page.load(name)
    case action
    when 'view'
      if page
        render 'show_page', page.name, :page => page
      else
        redirect Uri.edit_page(name)
      end
    when 'edit'
      page ||= Page.new(name)
      render 'edit_page', "Editing #{page.name}", :page => page
    end
  end
  
  def post(name, action=nil)
    page = Page.new(name, @input['content'])
    page.save
    redirect Uri.page(page.name)
  end
end

class NewPageController < WikiController
  def initialize
    super '/new'
  end
  
  def get
    render 'new_page', 'Add page', :page => Page.new
  end
  
  def post
    page = Page.new(@input['name'], @input['content'])
    unless Page.exists?(page.name)
      page.save
      redirect Uri.page(page.name)
    else
      render 'new_page', 'Add page', :page => page, :error => "A page named #{page.name} already exists"
    end
  end
end

class ListController < WikiController
  def initialize
    super '/list'
  end
  
  def get
    render 'list_pages', 'All pages', :pages => Page.list
  end
end

ROUTES = [ 
  [ '/', '/page/Home' ],
  [ '/page', PageController.new ],
  [ '/new', NewPageController.new ],
  [ '/list', ListController.new ]
]

Server.new(ADDR, PORT, ROUTES).start
