# This is the framework for controllers and views extracted from Satellite

%w{ configuration rubygems fileutils tempfile mongrel }.each {|l| require l }

def escape(s); Mongrel::HttpRequest.escape(s); end
def unescape(s); Mongrel::HttpRequest.unescape(s); end

# never subclass Controller directly! instead, use this method which creates a
# subclass with embedded route information
def controller(*routes)
  c = Class.new(Framework::Controller)
  c.class_eval { define_method(:routes) { routes } }
  c
end

def log_level(level)
  case level
  when :error : 1
  when :warn  : 2
  when :info  : 3
  when :debug : 4
  else          5
  end
end

def log(level, msg)
  if (log_level(CONF.log_level) >= log_level(level))
    puts "[#{level.to_s.upcase}] #{msg}"
  end
end

def save_file(input, destination)
  log :debug, "Saving #{input} to #{destination}"

  # create the destination directory if it doesn't already exist
  dir = File.dirname(destination)
  FileUtils.mkdir_p(dir) unless File.exists?(dir)

  # copy the input to the destination file
  if input.is_a?(Tempfile)
    FileUtils.cp(input.path, destination)
  elsif input.is_a?(StringIO)
    File.open(destination, 'w') { |f| f << input.read }
  elsif input.is_a?(String)
    File.open(destination, 'w') { |f| f << input }
  else
    raise ArgumentError.new("don't know how to save a #{input.class}")
  end
end

# Framework classes
module Framework

  # base controller class
  # - methods extending this should implement get and/or post methods
  # - this class should never be subclassed directly! instead, use the
  #   controller(*routes) method
  class Controller
    def redirect(uri)
      log :info, "Redirecting to #{uri}"
      @response.start(303) do |head, out|
        head['Location'] = uri
      end
    end

    def render(template, context={})
      log :info, "Rendering #{template}"
      @response.start(200) do |head, out|
        head['Content-Type'] = 'text/html'
        inner = process_template(template, context)
        context.store(:inner, inner)
        out.write process_template('structure', context)
      end
    end

    def respond(str, code=200)
      log :info, "Responding with '#{code}: #{str}'"
      @response.start(code) do |head, out|
        head['Content-Type'] = 'text/plain'
        out.write str
      end
    end
    
    def process_template(template, context={})
      markup = open(template_path(template)).read
      partial_function = lambda {|*a| t, h = *a; process_template("_#{t}", h || {}) }
      Erubis::Eruby.new(markup).evaluate(context.merge({ :partial => partial_function }))
    end

    def template_path(template)
      File.join(CONF.template_dir, "#{template}.rhtml")
    end

    def to_s
      self.class.to_s
    end
  end

  # router class
  # - handlers all the request routing and argument parsing
  class Router
    class NoPathFound < RuntimeError; end

    def initialize(controller_module)
      add_controllers(Router.find_controllers(controller_module))
    end

    class << self
      # given a module containing controllers, inspect the constants and return controller instances
      def find_controllers(controller_module)
        controller_module.constants.map do |c|
          eval("#{controller_module}::#{c}")
        end.select do |c|
          c.kind_of? Class
        end.map do |c|
          c.new
        end.select do |c|
          c.kind_of? Controller
        end
      end

      def regex(route)
        /^#{route}\/?\??$/
      end

      def extract_arguments(uri, regex)
        log :debug, "Extracting arguments from '#{uri}'"
        log :debug, "  Attempting to match #{regex}"
        if m = regex.match(uri)
          log :debug, "    Found #{m.size - 1} arguments"
          return m.to_a[1..-1].collect {|a| unescape(a) }
        end
        []
      end
    end

    # add the given controller instances to the routing table
    def add_controllers(controllers)
      @route_map ||= {}
      log :info, "Router: adding controllers to route map: #{controllers.join(',')}"
      controllers.each { |c| c.routes.each {|r| @route_map[r] = c } }
      build_index
    end

    # priotize the routes in the routing table (keep an array of sorted keys to the route_map hash table)
    def build_index
      @routes = @route_map.keys.sort
    end

    # process a given uri, returning the controller instance and extracted uri arguments
    def process(uri)
      # check if necessary to auto-reload app on each request (if turned on in config)
      if CONF.auto_reload
        log :debug, "Checking if app needs to be reloaded"
        RELOADER.reload_app
      end

      # routing
      log :debug, "Router: attempting to match #{uri}"
      @routes.each do |r|
        regex = Router.regex(r)
        log :debug, "  Trying #{regex}"
        if regex.match(uri)
          # route r is correct
          controller = @route_map[r]
          args = Router.extract_arguments(uri, regex)
          log :debug, "    Success! controller is #{controller}, args are #{args.join(', ')}"
          return controller, args
        end
      end
      raise NoPathFound
    end

  end

  # request handler
  # - wraps mongrel HttpHandler and interacts with Router and Controllers
  class RequestHandler < Mongrel::HttpHandler
    def initialize(controller_module)
      @router = Router.new(controller_module)
    end

    def process(request, response)
      begin
        http_method, request_uri = request.params['REQUEST_METHOD'], request.params['REQUEST_URI']
        log :info, "#{http_method} #{request_uri}"
        controller, args = @router.process(request_uri)

        # TODO instead of injecting instance variables, can we use metaprogramming
        # to define get/post methods that have response and input as args?

        # inject the response object
        controller.instance_variable_set("@response", response)

        case http_method.upcase
        when 'GET'
          # call controller get method
          controller.get(*args)
        when 'POST'
          begin
            if upload_data = process_file_upload(request)
              # inject input object
              controller.instance_variable_set("@input", upload_data)
            else
              # inject input object
              controller.instance_variable_set("@input", hashify(io_to_string(request.body)))
            end

            # call controller post method
            controller.post(*args)
          rescue RuntimeError => e
            log :debug, "Encountered runtime error in POST processing -- returning 500\n#{e.to_s}"
            controller.respond(e.to_s, 500)
          end
        else
          raise ArgumentError.new("Only GET and POST are supported, not '#{http_method}'")
        end
      rescue Router::NoPathFound
        log :warn, "No route found for '#{request_uri}', returning 404."
        response.start(404) do |head, out|
          head['Content-Type'] = 'text/html'
          out.write("<pre>404, baby. aint nothing at '#{request_uri}'</pre>")
        end
      rescue Exception => e
        log :error, "Error occured:\n#{e.class}: #{e.message}\n" +
          e.backtrace.collect {|s| sprintf "%8s\n", s }.join
        response.start(500) do |head, out|
          head['Content-Type'] = 'text/html'
          out.write '<pre>'
          out.write "#{e.class}: #{e.message}\n"
          out.write e.backtrace.collect {|s| "        #{s}\n" }.join
          out.write '</pre>'
        end
      end
    end

    def hashify(str, hash={})
      puts "hashifying string: #{str}"
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
        raise ArgumentError.new("don't know how to read a #{input.class}")
      end
    end

  private

    # process file uploads
    # this method is borrowed from Camping (but modified to not rely on camping libs)
    #
    # Copyright (c) 2006 why the lucky stiff
    #
    # Permission is hereby granted, free of charge, to any person obtaining a copy
    # of this software and associated documentation files (the "Software"), to
    # deal in the Software without restriction, including without limitation the
    # rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
    # sell copies of the Software, and to permit persons to whom the Software is
    # furnished to do so, subject to the following conditions:
    #
    # The above copyright notice and this permission notice shall be included in
    # all copies or substantial portions of the Software.
    #
    # THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    # IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    # FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
    # THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
    # IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
    # CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
    def process_file_upload(request)
      qs = {}
      @in = request.body
      if %r|\Amultipart/form-data.*boundary=\"?([^\";,]+)|n.match(request.params['CONTENT_TYPE'])
        b = /(?:\r?\n|\A)#{Regexp::quote("--#$1")}(?:--)?\r$/
        until @in.eof?
          fh={}
          for l in @in
            case l
            when "\r\n": break
            when /^Content-Disposition: form-data;/
              $'.scan(/(?:\s(\w+)="([^"]+)")/).each do |key,value|
                fh[key.to_sym] = value
              end
            when /^Content-Type: (.+?)(\r$|\Z)/m
              log :info, "=> fh[type] = #$1"
              fh[:type] = $1
            end
          end
          fn=fh[:name]
          o=if fh[:filename]
            o=fh[:tempfile]=Tempfile.new(:C)
            o.binmode
          else
            fh=""
          end
          while l=@in.read(16384)
            if l=~b
              o<<$`.chomp
              @in.seek(-$'.size,IO::SEEK_CUR)
              break
            end
            o<<l
          end
          qs[fn]=fh if fn
          fh[:tempfile].rewind if fh.is_a? Hash
        end
        qs
      else
        nil
      end
    end
  end

  # server
  # - defines a mongrel http server for the app
  # - static requests are handled by mongrel
  # - other requests are handled by RequestHandler
  class Server
    def initialize(addr, port, controller_module)
      @addr, @port, @controller_module = addr, port, controller_module
    end

    def start
      h = Mongrel::HttpServer.new(@addr, @port)
      h.register('/', RequestHandler.new(@controller_module))
      h.register('/static', Mongrel::DirHandler.new('static/'))
      h.register('/favicon.ico', Mongrel::Error404Handler.new(''))
      yield(h)
      log :info, "** #{CONF.app_name} is now running at http://#{@addr}:#{@port}/"
      h.run.join
    end
  end
end