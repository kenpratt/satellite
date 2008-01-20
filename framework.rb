# This is the extracted framework supporting the wiki app

class RequestHandler < Mongrel::HttpHandler
  def initialize(*uri_formats)
    @uri_formats = uri_formats
  end

  def process(request, response)
    begin
      @request, @response = request, response
      args = extract_args(@request.params['REQUEST_URI'])
      http_method = @request.params['REQUEST_METHOD'] || ''
      case http_method.upcase
      when 'GET'
        get(*args)
      when 'POST'
        @input = hashify(io_to_string(@request.body))
        post(*args)
      else
        raise ArgumentError("Only GET and POST are supported, not '#{http_method}'")
      end
    rescue Exception => e
      @response.start(500) do |head, out|
        head['Content-Type'] = 'text/html'
        out.write '<pre>'
        out.write "#{e.class}: #{e.message}\n"
        out.write e.backtrace.collect {|s| "        #{s}\n" }.join
        out.write '</pre>'
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
      head['Location'] = uri
    end
  end
  
  def render(template, context)
    @response.start(200) do |head, out|
      head['Content-Type'] = 'text/html'
      inner = Erubis::Eruby.new(open("templates/#{template}.rhtml").read).evaluate(context)
      out.write Erubis::Eruby.new(open("templates/structure.rhtml").read).evaluate({:content => inner})
    end
  end
  
  def process_template(template, context)
    Erubis::Eruby.new(open("templates/#{template}.rhtml").read).evaluate(context)
  end
end

def save_file(input, destination)
  if input.is_a?(Tempfile)
    FileUtils.cp(input.path, destination)
  elsif input.is_a?(StringIO)
    File.open(destination, 'w') { |f| f << input.read }
  elsif input.is_a?(String)
    File.open(destination, 'w') { |f| f << input }
  else
    raise ArgumentError("don't know how to save a #{input.class}")
  end
end

def log(s)
  puts s
end
