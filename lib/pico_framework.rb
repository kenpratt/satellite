# PicoFramework is an itty-bitty framework with a Rack interface. Like, really
# small. A trillionth the size of giants like Rails and Merb.
#
# It supports controllers and rhtml templates and file uploads and that is
# pretty much it.
#
# By default, it uses mongrel, but it would be *super* easy to use any other
# Ruby app server (just change the Rack handler in PicoFramwork::Server.start).
#

%w{ configuration rubygems rack mongrel fileutils tempfile logger }.each {|l| require l }

module PicoFramework
  # base controller class
  # - methods extending this should implement get and/or post methods
  # - this class should never be subclassed directly! instead, use the
  #   controller(*routes) method
  class Controller
    class << self
      # render a template to a string
      def render(template, context)
        inner = process_template(template, context)
        context.store(:inner, inner)
        process_template('structure', context)
      end
      
      # construct a Rack::Response object
      # block should take output as arg and call output.write
      def respond(status, header={}, &block)
        Rack::Response.new([], status, header).finish(&block)
      end

      # return the 404 page
      def return_404(request_uri)
        log.warn "No route found for '#{request_uri}', returning 404."
        respond(404) do |out|
          if File.exists? template_path('404')
            out.write render('404', :request_uri => request_uri)
          else
            out.write "<pre>404, baby. There ain't nothin' at #{request_uri}.</pre>"
          end
        end
      end

    private
      
      # process an erubis template with the provided context
      def process_template(template, context={})
        markup = open(template_path(template)).read
        partial_function = lambda {|*a| t, h = *a; process_template("_#{t}", h || {}) }
        context = context.merge({ :partial => partial_function })
        context[:error] ||= nil
        Erubis::Eruby.new(markup).evaluate(context)
      end

      # template path is configurable
      def template_path(template)
        File.join(CONF.template_dir, "#{template}.rhtml")
      end
    end

    # 200: render template
    def render(template, context={})
      log.debug "Rendering #{template}"
      self.class.respond(200) do |out|
        out.write self.class.render(template, context)
      end
    end

    # 303: redirect
    def redirect(uri)
      log.debug "Redirecting to #{uri}"
      self.class.respond(303, { 'Location' => uri })
    end

    # respond plain-text
    def respond_plaintext(str, status=200)
      log.debug "Responding with '#{status}: #{str}'"
      self.class.respond(status, { 'Content-Type' => 'text/plain' }) do |out|
        out.write str
      end
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
          c.kind_of?(Class) && c.ancestors.include?(Controller)
        end.map do |c|
          c.new
        end
      end

      def regex(route)
        /^#{route}\/?\??$/
      end

      def extract_arguments(uri, regex)
        log.debug "Extracting arguments from '#{uri}'"
        log.debug "  Attempting to match #{regex}"
        if m = regex.match(uri)
          log.debug "    Found #{m.size - 1} arguments"
          return m.to_a[1..-1].collect {|a| unescape(a) }
        end
        []
      end
    end

    # add the given controller instances to the routing table
    def add_controllers(controllers)
      @route_map ||= {}
      log.debug "Router: adding controllers to route map: #{controllers.join(',')}"
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
        log.debug "Checking if app needs to be reloaded"
        RELOADER.reload_app
      end

      # routing
      log.debug "Router: attempting to match #{uri}"
      @routes.each do |r|
        regex = Router.regex(r)
        log.debug "  Trying #{regex}"
        if regex.match(uri)
          # route r is correct
          controller = @route_map[r]
          args = Router.extract_arguments(uri, regex)
          log.debug "    Success! controller is #{controller}, args are #{args.join(', ')}"
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
        log.debug 'Hit RequestHandler.call()'

        request = Rack::Request.new(env)
        log.debug "#{request.request_method} #{request.path_info}"

        controller, args = @router.process(request.path_info)

        log.debug "Referrer: #{request.env['HTTP_REFERER']}"

        # TODO instead of injecting instance variables, can we use metaprogramming
        # to define get/post methods that have referrer and input as args?

        # inject referring page
        controller.instance_variable_set("@referrer", request.env['HTTP_REFERER'])

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
        Controller.return_404(request.path_info)
      end
    end
  end

  # runnable server class
  # expects RequestHandler to implement teh Rack interface (a call(env) method)
  class Server
    def initialize(addr, port, controller_module, static_dirs={})
      @addr, @port, @controller_module, @static_dirs = addr, port, controller_module, static_dirs

      # initialize logger
      FileUtils::mkdir_p CONF.log_dir
      logger = Logger.new(File.join(CONF.log_dir, CONF.log_file_name))
      logger.level = Logger.const_get(CONF.log_level.to_s.upcase)
      PicoFramework.logger = logger
    end

    # set up the Rack stack to use (depends on configuration)
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
      app = Rack::CommonLogger.new(app, PicoFramework.logger)
      app = Rack::ShowExceptions.new(app) if CONF.prettify_exceptions

      app
    end
    
    # start app server. uses mongrel by default, but that's easy to change.
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

  class << self
    def logger=(new_logger)
      @@logger = new_logger
    end

    def logger
      @@logger ||= nil
    end
  end
end

# some kernel-level helper methods

# shortcuts for URI escaping
def escape(s); Rack::Utils.escape(s); end
def unescape(s); Rack::Utils.unescape(s); end

# never subclass Controller directly! instead, use this method which creates a
# subclass with embedded route information
def controller(*routes)
  c = Class.new(PicoFramework::Controller)
  c.class_eval { define_method(:routes) { routes } }
  c
end

# swallow all methods passed in
class Zombie
  def method_missing(name, *args, &block)
    # do nothing
  end
end

# shortcut to logger
def log
  if logger = PicoFramework.logger
    logger
  else
    # if no logger is set up, use a zombie class instead
    puts "No logger is set up -- logging to /dev/null"
    Zombie.new
  end
end

# save some input (string, tempfile, etc) to the filesystem
def save_file(input, destination)
  log.debug "Saving #{input} to #{destination}"

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
