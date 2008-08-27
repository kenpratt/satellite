# This is the main Satellite app. All business logic is contained here.
# - configuration is in config.rb
# - controller and view framework aka PicoFramework is in pico_framework.rb
# - "database" (Git interface) aka GitDB is in git_db.rb

%w{ configuration pico_framework git_db rubygems metaid redcloth open-uri erubis coderay }.each {|l| require l }

VALID_FILENAME_CHARS = '\w \!\@\#\$\%\^\&\(\)\-\_\+\=\[\]\{\}\,\.'

require 'wiki_markup'

# reopen pico controller class to provide some app-specific logic
module Pico
  class Controller
    inject :conf
    inject :urimap

    # more context for the render methods
    def app_context(title)
      { 
        :title     => title,
        :uri       => urimap,
        :conf      => conf,
        :pages     => Satellite::Models::Pages.new.list,
        :conflicts => Satellite::Models::Pages.new.conflicts,
        :referrer  => @referrer
      }
    end

    # redefine render method to take in more paramaters
    alias :original_render :render
    def render(template, title, context={})
      context.merge!(app_context(title))
      original_render(template, context)
    end

    # redefine 404 rendering too
    class NotFound
      def content
        begin
          context = Controller.new.app_context('404, Baby').merge({:request_uri => @request_uri})
          Renderer.new('404', context).render_html
        rescue Renderer::NoTemplateFound
          "<pre>404, baby. There ain't nothin' at #{@request_uri}.</pre>"
        end
      end
    end

    # for controllers that can share some page/upload logic
    # in general, pages should redirect back to the page itself,
    # and uploads should redirect back to the list page
    def page_or_upload(type, name)
      case type
      when 'page'
        @klass = Satellite::Models::Page
        @cancel_uri = @referrer || urimap.page(name)
      when 'upload'
        @klass = Satellite::Models::Upload
        @cancel_uri = @referrer || urimap.list
      end
    end

    # process the return_to uri
    def return_to(bad_uri=nil)
      return_to = @input['return_to']
      if return_to
        return_to.strip!
        if return_to.any?
          if bad_uri
            return return_to unless return_to.match(/#{bad_uri}$/)
          else
            return return_to
          end
        end
      end
      nil
    end

    # process a file upload
    def process_upload
      logger.debug "Uploaded: #{@input}"
      filename = @input['Filedata'][:filename].strip

      # save upload
      upload = Satellite::Models::Upload.new(filename)
      upload.save(@input['Filedata'][:tempfile])

      # allow extra post-save logic
      yield upload if block_given?

      # respond with plain text (since it's a flash plugin)
      Success.new('Thanks!', 'Content-Type' => 'text/plain').response
    end
  end
end

module Satellite
  # "Hunk" is a model representing a file stored in the backend.
  # Hunks are saved locally in the filesystem, changes are committed to a
  # local Git repository which is mirrored to a master repository.
  # "Pages" and "Uploads" are types of Hunks.
  #
  # "Page" is a Hunk representing a wiki page.
  # "Upload" is a Hunk representing an uploaded file.
  #
  # Methods that operate on a specific page/upload are in Hunk/Page/Upload.
  # Methods that operate on more than one page/upload are in Hunks/Pages/Uploads.
  module Models
    PAGE_DIR = 'pages'
    UPLOAD_DIR = 'uploads'

    class Model
      inject :conf
      inject :logger
      inject :db
      inject :wikimarkup
    end

    class Hunks < Model
      def initialize(item_class, content_dir)
        @item_class, @content_dir = item_class, content_dir
      end

      def list
        Dir[File.join(path, '*')].collect {|s| @item_class.new(parse_name(s)) }.sort
      end

      # "path/to/hunks/"
      def path; File.join(conf.data_dir, @content_dir); end

      # try to extract the page name from the path
      def parse_name(path)
        if path =~ /^(.*\/)?([#{VALID_FILENAME_CHARS}]+)$/
          $2
        else
          path
        end
      end
    end

    class Pages < Hunks
      def initialize
        super(Page, PAGE_DIR)
      end

      def search(query)
        out = {}
        db.search(query).each do |file,matches|
          page = Page.new(parse_name(file))
          out[page] = matches.collect do |line,text|
            text = wikimarkup.process(text)
            text.gsub!(/<\/?[^>]*>/, '')
            [line, text]
          end
        end
        out
      end

      def conflicts
        db.conflicts.collect {|c| Page.new(parse_name(c)) }.sort
      end

      # chop off the .textile
      alias :original_parse_name :parse_name
      def parse_name(path)
        original_parse_name(path).sub(/\.textile$/, '')
      end
    end

    class Uploads < Hunks
      def initialize
        super(Upload, UPLOAD_DIR)
      end
    end

    class Hunk < Model
      include Comparable

      def initialize(content_dir, name)
        @content_dir = content_dir
        self.name = name
      end

      def name
        @name
      end

      def exists?
        File.exists?(filepath)
      end

      def self.load(name)
        hunk = self.new(name)
        hunk.load
        hunk
      end

      def load
        raise GitDb::FileNotFound.new("#{@item_class} #{name} does not exist") unless exists?
        self
      end

      def save(input)
        begin
          raise ArgumentError.new("Saved name can't be blank") unless name.any?
          save_file(input, filepath)
          db.save(local_filepath, "Satellite: saving #{name}")
        rescue GitDb::ContentNotModified
          logger.debug "Hunk.save(): #{name} wasn't modified since last save"
        end
      end

      def rename(new_name)
        old_name = name
        self.name = new_name
        raise ArgumentError.new("New name can't be blank") unless name.any?
        local_filepath_old = self.class.new(old_name).local_filepath
        db.mv(local_filepath_old, local_filepath, "Satellite: renaming #{old_name} to #{name}")
      end

      def delete!
        db.rm(local_filepath, "Satellite: deleting #{name}")
      end

      # "foo.ext" (just the name by default)
      def filename; name; end

      # "pages/foo.ext"
      def local_filepath; File.join(@content_dir, filename); end

      # "path/to/pages/foo.ext"
      def filepath; File.join(conf.data_dir, @content_dir, filename); end

      # case-insensitive alphabetical order
      def <=>(other)
        name.downcase <=> other.name.downcase
      end

    private

      def valid_name?(name)
        name =~ /^[#{VALID_FILENAME_CHARS}]*$/
      end

      def name=(name)
        name.strip!
        raise ArgumentError.new("Name is invalid: #{name}") unless valid_name?(name)
        @name = name
      end
    end

    class Page < Hunk
      def initialize(name='', body='')
        super(PAGE_DIR, name)
        self.body = body # call set method instead of setting directly
      end

      def body(format=nil)
        case format
        when :html
          to_html
        else
          @body
        end
      end

      def body=(str='')
        if str.any?
          # fix line endings coming from browser
          str.gsub!(/\r\n/, "\n")

          # end page with newline if it doesn't have one
          str += "\n" unless str[-1..-1] == "\n"
        end
        @body = str
      end

      alias :original_load :load
      def load
        original_load
        raw = open(filepath).read
        self.body = raw
        self
      end

      alias :original_save :save
      def save
        original_save(body)
      end

      # "foo.textile"
      def filename; "#{name}.textile"; end

      # sort home above other pages, otherwise (case-insensitive) alphabetical order
      def <=>(other)
        if name == 'Home'
          -1
        elsif other.name == 'Home'
          1
        else
          name.downcase <=> other.name.downcase
        end
      end

      def to_html
        wikimarkup.process(@body)
      end
    end

    class Upload < Hunk
      def initialize(name='')
        super(UPLOAD_DIR, name)
      end
    end
  end

  # controllers definitions
  module Controllers
    VALID_URI_CHARS = '\w \+\%\-\.'
    NAME = "([#{VALID_URI_CHARS}]+)"

    VALID_SEARCH_STRING_CHARS = '0-9a-zA-Z\+\%\`\~\!\^\*\(\)\_\-\[\]\{\}\\\|\'\"\.\<\>'
    SEARCH_STRING = "([#{VALID_SEARCH_STRING_CHARS}]+)"

    class IndexController < controller '/'
      def get; redirect urimap.home; end
      def post; redirect urimap.home; end
    end

    class PageController < controller "/page/#{NAME}", "/page/#{NAME}/(edit|resolve)"
      def get(name, action='view')
        # load page
        begin
          page = Models::Page.load(name)
        rescue GitDb::FileNotFound
          page = nil
        end

        # do stuff
        case action
        when 'view'
          if page
            render 'show_page', page.name, :page => page
          else
            redirect urimap.edit_page(name)
          end
        when 'edit'
          page ||= Models::Page.new(name)
          render 'edit_page', "Editing #{page.name}", :page => page, :cancel_uri => (@referrer || urimap.page(name))
        when 'resolve'
          if page
            render 'resolve_conflict_page', "Resolving #{page.name}", :page => page, :cancel_uri => (@referrer || urimap.page(name))
          else
            redirect urimap.edit_page(name)
          end
        else
          raise RuntimeError.new("PageController does not support the '#{action}' action.")
        end
      end

      def post(name, action=nil)
        page = Models::Page.new(name, @input['content'])
        page.save
        redirect return_to || urimap.page(page.name)
      end
    end

    class NewPageController < controller '/new'
      def get
        render 'new_page', 'Add page', :page => Models::Page.new, :cancel_uri => (@referrer || urimap.list)
      end

      def post
        page = Models::Page.new(@input['name'].strip, @input['content'])
        unless page.exists?
          page.save
          redirect urimap.page(page.name) # don't worry about return_to
        else
          render 'new_page', 'Add page', :page => page, :error => "A page named #{page.name} already exists"
        end
      end
    end

    class RenameController < controller "/(page|upload)/#{NAME}/rename"
      def get(type, name)
        page_or_upload(type, name)
        hunk = @klass.load(name)
        render 'rename', "Renaming #{hunk.name}", :hunk => hunk, :cancel_uri => @cancel_uri
      end

      def post(type, name)
        page_or_upload(type, name)
        hunk = @klass.new(name)
        hunk.rename(@input['new_name'].strip)

        # figure out where to redirect to
        uri = return_to(urimap.send(type, name))
        if uri
          redirect uri
        elsif @klass == Models::Page
          redirect urimap.page(hunk.name)
        elsif @klass == Models::Upload
          redirect urimap.list
        end
      end
    end

    class DeleteController < controller "/(page|upload)/#{NAME}/delete"
      def get(type, name)
        page_or_upload(type, name)
        hunk = @klass.load(name)
        render 'delete', "Deleting #{hunk.name}", :hunk => hunk, :cancel_uri => @cancel_uri
      end

      def post(type, name)
        page_or_upload(type, name)
        hunk = @klass.load(name)
        hunk.delete!
        redirect return_to(urimap.send(type, name)) || urimap.list
      end
    end

    class ListController < controller '/list'
      def get
        # @pages is populated for all pages, since it is used in goto jump box
        render 'list', 'All pages and uploads', :uploads => Models::Uploads.new.list
      end
    end

    class SearchController < controller '/search'
      def get
        if query = @input['query']
          logger.debug "searched for: #{query}"
          results = Models::Pages.new.search(query)
          render 'search', "Searched for: #{query}", :query => query, :results => results
        else
          render 'search', 'Search'
        end
      end
    end

    class PageUploadController < controller "/page/#{NAME}/upload"
      def post(name)
        process_upload do |upload|
          # add upload to current page
          page = Models::Page.load(name)
          page.body += "\n\n* {{upload:#{upload.name}}}"
          page.save
        end
      end
    end

    class UploadController < controller '/upload', "/upload/#{NAME}"
      def get(name='')
        # files are served up directly by Mongrel (at URI "/uploads")
        redirect urimap.upload(name)
      end

      def post
        process_upload
      end
    end

    class HelpController < controller '/help'
      def get
        render 'help', 'Help'
      end
    end
  end

  # uri mappings
  # TODO somehow generate these from routing table?
  class UriMap
    def initialize(static_dir)
      @static_dir = static_dir
    end

    def page(name) "/page/#{escape(name)}" end
    def edit_page(name) "/page/#{escape(name)}/edit" end
    def rename(hunk)
      case hunk
      when Models::Page
        "/page/#{escape(hunk.name)}/rename"
      when Models::Upload
        "/upload/#{escape(hunk.name)}/rename"
      else
        logger.error "#{hunk} is neither a Page nor an Upload"
        ""
      end
    end
    def delete(hunk)
      case hunk
      when Models::Page
        "/page/#{escape(hunk.name)}/delete"
      when Models::Upload
        "/upload/#{escape(hunk.name)}/delete"
      else
        logger.error "#{hunk} is neither a Page nor an Upload"
        ""
      end
    end
    def resolve_conflict(name) "/page/#{escape(name)}/resolve" end
    def new_page() '/new' end
    def list() '/list' end
    def home() '/page/Home' end
    def search() '/search' end
    def upload(name) "/uploads/#{escape(name)}" end
    def upload_file(page_name=nil)
      if page_name
        "/page/#{escape(page_name)}/upload"
      else
        "/upload"
      end
    end
    def rename_upload(name) "/upload/#{escape(name)}/rename" end
    def delete_upload(name) "/upload/#{escape(name)}/delete" end
    def help() '/help' end
    def static(file)
      lastmod = File.ctime(File.join(@static_dir, file)).strftime('%Y%m%d%H%M')
      "/static/#{file}?#{lastmod}"
    end
  end

  class Server
    attr_reader :boot

    def initialize(env)
      @env = env
      @boot = Pico::Bootstrapper.new(@env, Satellite::Controllers)
      setup_satellite_dependencies
    end

    def application
      app = @boot.create_application do |app, container|
        add_uploads_handler(app, container.conf)
      end
      app
    end

    def start
      @boot.run do |app, container|
        add_uploads_handler(app, container.conf)
        DbSynchronizer.new(container.conf.sync_frequency).start
      end
    end

  private

    # create UriMap, DB, and WikiMarkup dependencies
    def setup_satellite_dependencies
      @boot.dependency_container.class_eval do
        def urimap
          Satellite::UriMap.new(container.conf.static_dir)
        end
        provide :db, GitDb
        provide :wikimarkup, Satellite::WikiMarkup
      end
    end

    def add_uploads_handler(app, conf)
      app.static_dirs.store('/uploads', File.join(conf.data_dir, Satellite::Models::UPLOAD_DIR))
    end
  end

  class DbSynchronizer
    inject :db
    inject :logger

    def initialize(sync_frequency)
      @sync_frequency = sync_frequency
    end

    def sync
      logger.info "Synchronizing with master repository."
      begin
        db.sync
      rescue GitDb::MergeConflict => e
        # TODO surface on front-end? already happens on page-load, though...
        logger.warn "Encountered conflicts during sync. The following files must be merged manually:" +
          db.conflicts.collect {|c| "  * #{c}" }.join("\n")
      rescue GitDb::ConnectionFailed
        logger.warn "Failed to connect to master repository during sync operation."
      end
      logger.info "Sync complete."
    end

    def start
      # kill the whole server if an unexpected exception is encounted in the sync
      Thread.abort_on_exception = true

      # spawn thread to sync with master repository
      Thread.new do
        while true
          sleep @sync_frequency
          sync
        end
      end
    end
  end
end
