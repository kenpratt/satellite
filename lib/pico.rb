require 'rubygems'
require 'rack'
require 'logger'
require 'erubis'

require File.join(File.expand_path(File.dirname(__FILE__)), 'configuration.rb')

# dependency injection library
require File.join(File.expand_path(File.dirname(__FILE__)), '../vendor/dissident/dissident.rb')

module Pico

  # base controller class
  # - methods extending this should implement get and/or post methods
  # - this class should never be subclassed directly! instead, use the
  #   controller(*routes) method
  class Controller
    inject :logger

    class Response
      def initialize(status, header={}, &block)
        @status, @header, @block = status, header, block
      end

      def response
        Rack::Response.new([], @status, @header).finish(&@block)
      end
    end

    # 200 OK
    class Success < Response
      def initialize(str, header={})
        super(200, header) do |out|
          out.write(str)
        end
      end
    end

    # 303 See Other
    class Redirect < Response
      def initialize(uri)
        super(303, { 'Location' => uri })
      end
    end

    # 404 Not Found
    class NotFound < Response
      def initialize(request_uri)
        @request_uri = request_uri
        super(404) do |out|
          out.write content
        end
      end

      # use 404 template if it exists
      def content
        begin
          Renderer.new('404', :request_uri => @request_uri).render_html
        rescue Renderer::NoTemplateFound
          "<pre>404, baby. There ain't nothin' at #{@request_uri}.</pre>"
        end
      end
    end

    def render(template, context={})
      logger.debug "Rendering #{template}"
      html = Renderer.new(template, context).render_html
      Success.new(html).response
    end

    def redirect(uri)
      logger.debug "Redirecting to #{uri}"
      Redirect.new(uri).response
    end
  end

  class Renderer
    class NoTemplateFound < RuntimeError; end

    inject :conf

    def initialize(template, context={})
      @template, @context = template, context
    end

    def render_html
      inner = process_template(@template, @context)
      @context.store(:inner, inner)
      process_template('structure', @context)
    end

  private

    # template path is configurable
    def template_path(template)
      File.join(conf.template_dir, "#{template}.rhtml")
    end

    # process an erubis template with the provided context
    def process_template(template, context={})
      begin
        markup = open(template_path(template)).read
        partial_function = lambda {|*a| t, h = *a; process_template("_#{t}", h || {}) }
        context = context.merge({ :partial => partial_function })
        context[:error] ||= nil
        Erubis::Eruby.new(markup).evaluate(context)
      rescue Errno::ENOENT => e
        raise NoTemplateFound.new(e)
      end
    end
  end

  # routes requests to controllers
  class Router
    class NoPathFound < RuntimeError; end

    inject :logger

    def route_map
      @route_map ||= {}
    end

    # add the controllers contained in the given module to the routing table
    def add_controller_module(controller_module)
      logger.debug "Router: adding controllers in #{controller_module} to route map"
      controllers = find_controllers(controller_module)
      add_controllers(controllers)
    end

    # add the given controller instances to the routing table
    def add_controllers(controllers)
      logger.debug "Router: adding controllers to route map: #{controllers.join(',')}"
      controllers.each { |c| c.routes.each {|r| route_map.store(r, c) } }
    end

    # process a given uri, returning the controller instance and extracted uri arguments
    def process(uri)
      logger.debug "Router: attempting to match #{uri}"
      route_map.keys.sort.each do |route|
        regex = /^#{route}\/?\??$/
        logger.debug "  Trying #{regex}"
        if regex.match(uri)
          # route is correct
          controller = route_map[route]
          args = extract_arguments(uri, regex)
          logger.debug "    Success! controller is #{controller}, args are #{args.join(', ')}"
          return controller, args
        end
      end
      raise NoPathFound
    end

  private

    # extract arguments encoded in the uri
    def extract_arguments(uri, regex)
      logger.debug "Extracting arguments from '#{uri}'"
      logger.debug "  Attempting to match #{regex}"
      if m = regex.match(uri)
        logger.debug "    Found #{m.size - 1} arguments"
        return m.to_a[1..-1].collect {|a| unescape(a) }
      end
      []
    end

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
  end

  # implements the Rack application interface
  class RequestHandler
    inject :logger

    def initialize(router)
      @router = router
    end

    def call(env)
      begin
        logger.debug 'Hit RequestHandler.call()'

        request = Rack::Request.new(env)
        logger.debug "#{request.request_method} #{request.path_info}"

        controller, args = @router.process(request.path_info)

        logger.debug "Referrer: #{request.env['HTTP_REFERER']}"

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
        Controller::NotFound.new(request.path_info).response
      end
    end
  end

  # bootstrap the dependency injection and start the app
  class Bootstrapper
    attr_reader :dependency_container

    def initialize(env, controller_module)
      @env, @controller_module = env, controller_module
      @dependency_container = Class.new(Dissident::Container)
      add_pico_dependencies
    end

    # just create the app instance -- don't actually run it
    def create_application
      Dissident.with @dependency_container do |container|
        # create the application
        app = Pico::Application.new(@controller_module)

        # optionally do some more set up before starting the server
        yield(app, container) if block_given?

        app
      end
    end

    # create an app server and start it
    def run(&proc)
      Dissident.with @dependency_container do |container|
        # create the application
        app = create_application(&proc)

        # start the app server
        app.create_server.start
      end
    end

  private

    # define the config and logger dependencies
    def add_pico_dependencies
      # set up conf
      @dependency_container.class_eval "def conf; Configuration.load(:#{@env}); end"

      # set up logger
      @dependency_container.class_eval do
        def logger
          FileUtils::mkdir_p container.conf.log_dir
          Logger.class_eval { alias :write :"<<" } unless Logger.instance_methods.include?("write")
          l = Logger.new(File.join(container.conf.log_dir, container.conf.log_file_name))
          l.level = Logger.const_get(container.conf.log_level.to_s.upcase)
          l
        end
      end
    end
  end

  # pico application
  class Application
    inject :conf
    inject :logger

    def initialize(controller_module)
      @controller_module = controller_module
    end

    # uri->directory mappings for directories to serve statically
    def static_dirs
      @static_dirs ||= { '/static' => conf.static_dir }
    end

    # create a Rack application stack
    def rack_app
      # primary app
      main = pico_app
      main = Rack::Lint.new(main)

      # static directories
      static_map = {}
      static_dirs.each {|uri,path| static_map[uri] = Rack::File.new(path) }

      # uri mappings
      app = Rack::URLMap.new({ '/' => main }.merge(static_map))

      # authentication
      if conf.authentication == :basic
        app = Rack::Auth::Basic.new(app, &conf.authenticator)
        app.realm = 'Pico'
      end

      # common middleware
      app = Rack::CommonLogger.new(app, logger)
      app = Rack::ShowExceptions.new(app) if conf.prettify_exceptions

      app
    end

    # create an app server
    def create_server
      Server.new(conf.app_name, conf.server_ip, conf.server_port, rack_app)
    end

  private

    # create a Rack-compatible application
    def pico_app
      router = Router.new
      router.add_controller_module(@controller_module)
      RequestHandler.new(router)
    end
  end

  # application server
  class Server
    def initialize(app_name, addr, port, rack_app)
      @app_name, @addr, @port, @rack_app = app_name, addr, port, rack_app
    end

    # start app server. uses mongrel by default, but that's easy to change.
    def start
      begin
        puts "** Starting #{@app_name}"
        Rack::Handler::Mongrel.run(@rack_app, :Host => @addr, :Port => @port) do |server|
          puts "** #{@app_name} is now running at http://#{@addr}:#{@port}/"
          trap(:INT) do
            server.stop
            puts "\n** Stopping #{@app_name}"
          end
        end
      rescue Errno::EADDRINUSE => e
        puts "** Port #{@port} is already in use"
      end
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
  c = Class.new(Pico::Controller)
  c.class_eval { define_method(:routes) { routes } }
  c
end

# save some input (string, tempfile, etc) to the filesystem
def save_file(input, destination)
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
