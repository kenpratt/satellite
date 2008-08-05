# This is the framework for controllers and views extracted from Satellite

%w{ configuration rubygems rack fileutils tempfile mongrel }.each {|l| require l }

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

def response(status, header={}, &block)
  Rack::Response.new([], status, header).finish(&block)
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
      response(303, { 'Location' => uri })
    end

    def render(template, context={})
      log :info, "Rendering #{template}"
      response(200) do |out|
        inner = process_template(template, context)
        context.store(:inner, inner)
        out.write process_template('structure', context)
      end
    end

    def respond(str, status=200)
      log :info, "Responding with '#{status}: #{str}'"
      response(status, { 'Content-Type' => 'text/plain' }) do |out|
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
  # call(env) method provides Rack interface 
  class RequestHandler
    def initialize(controller_module)
      @router = Router.new(controller_module)
    end

    def call(env)
      begin
        log :debug, 'Hit RequestHandler.call()'

        request = Rack::Request.new(env)
        log :info, "#{request.request_method} #{request.path_info}"

        controller, args = @router.process(request.path_info)

        log :debug, "Referrer: #{request.referrer}"

        # TODO instead of injecting instance variables, can we use metaprogramming
        # to define get/post methods that have referrer and input as args?

        # inject referring page
        controller.instance_variable_set("@referrer", request.referrer)

        # inject GET & POST params
        controller.instance_variable_set("@input", request.params)

        if request.get?
          controller.get(*args)
        elsif request.post?
          controller.post(*args)
        else
          raise ArgumentError.new("Only GET and POST are supported, not #{request.request_method}")
        end
      rescue Router::NoPathFound
        log :warn, "No route found for '#{request.path_info}', returning 404."
        response(404) do |out|
          out.write("<pre>404, baby. There ain't nothin' at #{request.path_info}.</pre>")
        end
      end
    end
  end

  # server
  # - defines a mongrel http server for the app
  # - static requests are handled by mongrel
  # - other requests are handled by RequestHandler
  class Server
    def initialize(addr, port, controller_module, static_dirs={})
      @addr, @port, @controller_module, @static_dirs = addr, port, controller_module, static_dirs
    end

    def application
      # primary app
      main = RequestHandler.new(@controller_module)
      main = Rack::Lint.new(main)
      
      # static directories
      static_dirs = { '/static' => CONF.static_dir }.merge(@static_dirs)
      static_dirs.each {|uri,path| static_dirs[uri] = Rack::File.new(path) }
      
      # uri mappings
      app = Rack::URLMap.new({ '/' => main }.merge(static_dirs))

      # common middleware
      app = Rack::CommonLogger.new(app)
      app = Rack::ShowExceptions.new(app)

      app
    end
    
    def start
      begin
        puts "** Starting #{CONF.app_name}"
        Rack::Handler::Mongrel.run(application, :Host => @addr, :Port => @port) do |server|
          puts "** #{CONF.app_name} is now running at http://#{@addr}:#{@port}/"
          trap(:INT) do
            server.stop
            puts "\n** Stopping #{CONF.app_name}"
          end
        end
      rescue Errno::EADDRINUSE => e
        puts "** Port #{@port} is already in use"
      end
    end
  end
end
