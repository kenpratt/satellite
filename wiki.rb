#!/bin/env ruby

%w{ rubygems mongrel metaid redcloth open-uri erubis }.each {|gem| require gem }

APPNAME = "Wiki"
ADDR, PORT = "0.0.0.0", 3000

def log(s)
  puts s
end

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

class WikiHandler < Mongrel::HttpHandler
  def initialize(*uri_formats)
    @uri_formats = uri_formats
  end

  def process(request, response)
    begin
      @request, @response = request, response
      args = extract_args(@request.params["REQUEST_URI"])
      http_method = @request.params["REQUEST_METHOD"] || ""
      case http_method.upcase
      when "GET"
        get(*args)
      when "POST"
        @input = hashify(io_to_string(@request.body))
        post(*args)
      else
        raise ArgumentError("Only GET and POST are supported, not '#{http_method}'")
      end
    rescue Exception => e
      @response.start(500) do |head, out|
        head["Content-Type"] = "text/html"
        out.write "<pre>"
        out.write "#{e.class}: #{e.message}\n"
        out.write e.backtrace.collect {|s| "        #{s}\n" }.join
        out.write "</pre>"
      end
    end
  end
  
  def extract_args(request_uri)
    log "Extracting arguments from '#{request_uri}'"
    @uri_formats.each do |fmt|
      log "  Attempting to match /^#{fmt}\\/?$/"
      if m = /^#{fmt}\/?$/.match(request_uri)
        log "    Found #{m.size - 1} arguments"
        return m.to_a[1..-1]
      end
    end
    []
  end
  
  def hashify(str, hash={})
    (str || '').split(/[&;] */n).each { |f| hash.store(*unescape(f).split('=', 2)) }
    hash
  end
  
  def io_to_string(input)
    if input.is_a?(Tempfile)
      open(input.path).read
    elsif input.is_a?(StringIO)
      input.read
    elsif input.is_a?(String)
      input
    else
      raise ArgumentError("don't know how to read a #{input.class}")
    end
  end
  
  def escape(s); Mongrel::HttpRequest.escape(s); end
  def unescape(s); Mongrel::HttpRequest.unescape(s); end
  
  def redirect(uri)
    @response.start(303) do |head, out|
      head["Location"] = uri
    end
  end
  
  def render(template, context)
    @response.start(200) do |head, out|
      head["Content-Type"] = "text/html"
      out.write Erubis::Eruby.new(open("templates/#{template}.rhtml").read).evaluate(context)
    end
  end
end

def save_file(input, destination)
  if input.is_a?(Tempfile)
    FileUtils.cp(input.path, destination)
  elsif input.is_a?(StringIO)
    File.open(destination, "w") { |f| f << input.read }
  elsif input.is_a?(String)
    File.open(destination, "w") { |f| f << input }
  else
    raise ArgumentError("don't know how to save a #{input.class}")
  end
end

# TODO it would be nice to have this be like camping, with something like < R "/page/(.+)"
# instead of the inherit block. the necessary method might look like:
#
# see: http://whytheluckystiff.net/articles/seeingMetaclassesClearly.html
# def R(uri_format)
#   Class.new(WikiHandler) do
#     meta_def(:uri_format) { uri_format }
#   end
# end
#
class PageController < WikiHandler
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

def start_mongrel
  h = Mongrel::HttpServer.new(ADDR, PORT)
  h.register("/page", PageController.new)
  h.register("/favicon.ico", Mongrel::Error404Handler.new(""))
  puts "** #{APPNAME} is now running at http://#{ADDR}:#{PORT}/"
  h.run.join
end

start_mongrel