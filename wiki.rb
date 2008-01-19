#!/bin/env ruby

%w{ rubygems mongrel metaid redcloth open-uri erubis }.each {|gem| require gem }

# TODO integtrate configuration into app definition so framework doesn't rely on these constants
APPNAME = "Wiki"
ADDR, PORT = "0.0.0.0", 3000

require 'framework'

class Page
  attr_reader :name
  attr_writer :body
  
  def initialize(name, body="")
    @name = name
    @body = body
  end
  
  def self.load(name)
    if File.exists?(filename(name))
      Page.new(name, open(filename(name)).read)
    else
      nil
    end
  end
  
  def self.filename(name); "content/#{name}.textile"; end
  def filename; Page.filename(name); end
  
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
class PageController < RequestHandler
  def initialize
    super "/page/(\\w+)", "/page/(\\w+)/(edit)"
  end
  
  def get(name, action="view")
    page = Page.load(name)
    case action
    when "view"
      if page
        render 'show_page', :page => page
      else
        redirect edit_uri(name)
      end
    when "edit"
      page ||= Page.new(name)
      render 'edit_page', :page => page, :submit_uri => page_uri(page)
    end
  end
  
  def post(name, action=nil)
    page = Page.new(name, @input['content'])
    page.save
    redirect page_uri(page)
  end
  
  def page_uri(input)
    name = if input.is_a?(Page)
        input.name
      elsif input.is_a?(String)
        input
      else
        raise ArgumentError("don't know how to make a uri out of a #{input.class}")
      end
    "/page/#{escape(name)}"
  end
  
  def edit_uri(input); "#{page_uri(input)}/edit"; end
end

# TODO moge mongrel into framework
def start_mongrel
  h = Mongrel::HttpServer.new(ADDR, PORT)
  h.register("/page", PageController.new) # TODO remove app logic from the framework code
  h.register("/favicon.ico", Mongrel::Error404Handler.new(""))
  puts "** #{APPNAME} is now running at http://#{ADDR}:#{PORT}/"
  h.run.join
end

start_mongrel