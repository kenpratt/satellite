# This is the main Satellite app. All business logic is contained here. 
# - configuration is in config.rb
# - controller and view framework is in framework.rb
# - "database" aka Git interface is in db.rb

%w{ configuration framework db rubygems metaid redcloth open-uri erubis coderay }.each {|l| require l }

module Satellite

  # model definitions go here
  module Models

    # "Page" is a model representing a wiki page
    # Pages are saved locally in the filesystem, changes are committed to a local
    # Git repository which is mirrored to a master repository
    class Page
      include Comparable

      VALID_NAME_CHARS = '\w \!\@\#\$\%\^\&\(\)\-\_\+\=\[\]\{\}\,\.'
      PAGE_DIR = 'pages'
    
      # -----------------------------------------------------------------------
      # class methods
      # -----------------------------------------------------------------------

      class << self
        def list
          Dir[filepath('*')].collect {|s| Page.new(parse_name(s)) }.sort
        end
        
        def search(query)
          out = {}
          Db.search(query).each do |file,matches|
            page = Page.new(parse_name(file))
            out[page] = matches.collect do |line,text|
              text = WikiMarkup.process(text)
              text.gsub!(/<\/?[^>]*>/, '')
              [line, text]
            end
          end
          out
        end

        def conflicts
          Db.conflicts.collect {|c| Page.new(parse_name(c)) }.sort
        end
        
        def load(name)
          if exists?(name)
            Page.new(name, open(filepath(name)).read)
          else
            raise Db::FileNotFound.new("Page #{name} does not exist")
          end
        end

        def exists?(name)
          File.exists?(filepath(name))
        end
        
        def valid_name?(name)
          name =~ /^[#{VALID_NAME_CHARS}]*$/
        end
        
        def rename(old_name, new_name)
          page = load(old_name)
          page.rename(new_name) if page
          page
        end

        # "foo.textile"
        def filename(name); "#{name}.textile"; end
        
        # "pages/foo.textile"
        def local_filepath(name); File.join(PAGE_DIR, filename(name)); end

        # "path/to/pages/foo.textile"
        def filepath(name); File.join(CONF.data_dir, PAGE_DIR, filename(name)); end
        
        # try to extract the page name from the path
        def parse_name(path)
          if path =~ /^(.*\/)?([#{VALID_NAME_CHARS}]+)\.textile$/
            $2
          else
            path
          end
        end
      end
  
      # -----------------------------------------------------------------------
      # instance methods
      # -----------------------------------------------------------------------

      def initialize(name='', body='')
        self.name = name
        self.body = body
      end
      
      def name
        @name
      end
      
      # name= method is private (see below)

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
  
      def save
        begin
          raise ArgumentError.new("Saved name can't be blank") unless name.any?
          save_file(@body, filepath)
          Db.save(local_filepath, "Satellite: saving #{name}")
        rescue Db::ContentNotModified
          log :debug, "Page.save(): #{name} wasn't modified since last save"
        end
      end
  
      def rename(new_name)
        old_name = name
        self.name = new_name
        raise ArgumentError.new("New name can't be blank") unless name.any?
        Db.mv(Page.local_filepath(old_name), local_filepath, "Satellite: renaming #{old_name} to #{name}")
      end
      
      def delete!
        Db.rm(local_filepath, "Satellite: deleting #{name}")
      end
    
      # sort home above other pages, otherwise alphabetical order
      def <=>(other)
        if name == 'Home'
          -1
        elsif other.name == 'Home'
          1
        else
          name <=> other.name
        end
      end
    
      def to_html
        WikiMarkup.process(@body)
      end
  
      def filename; Page.filename(name); end
      def local_filepath; Page.local_filepath(name); end
      def filepath; Page.filepath(name); end
    
    private

      def name=(name)
        name.strip!
        raise ArgumentError.new("Name is invalid: #{name}") unless Page.valid_name?(name)
        @name = name
      end
    end

    # all the wiki markup stuff should go in here
    class WikiMarkup
      WIKI_LINK_FMT = /\{\{([#{Page::VALID_NAME_CHARS}]+)\}\}/

      AUTO_LINK_RE = %r{
                      (                          # leading text
                        <\w+.*?>|                # leading HTML tag, or
                        [^=!:'"/]|               # leading punctuation, or
                        ^                        # beginning of line
                      )
                      (
                        (?:https?://)|           # protocol spec, or
                        (?:www\.)                # www.*
                      )
                      (
                        [-\w]+                   # subdomain or domain
                        (?:\.[-\w]+)*            # remaining subdomains or domain
                        (?::\d+)?                # port
                        (?:/(?:(?:[~\w\+@%=-]|(?:[,.;:][^\s$]))+)?)* # path
                        (?:\?[\w\+@%&=.;-]+)?    # query string
                        (?:\#[\w\-]*)?           # trailing anchor
                      )
                      ([[:punct:]]|\s|<|$)       # trailing text
                     }x unless const_defined?(:AUTO_LINK_RE)

      class << self
        def process(str)
          str = process_code_blocks(str)
          str = process_wiki_links(str)
          str = textile_to_html(str)
          str = autolink(str)
          str
        end

      private

        # code blocks are like so (where lang is ruby/html/java/c/etc):
        # {{{(lang)
        # @foo = 'bar'
        # }}}
        def process_code_blocks(str)
          str.gsub(/\{\{\{([\S\s]+?)\}\}\}/) do |s|
            code = $1
            if code =~ /^\((\w+)\)([\S\s]+)$/
              lang, code = $1.to_sym, $2.strip
            else
              lang = :plaintext
            end
            code = CodeRay.scan(code, lang).html.div
            "<notextile>#{code}</notextile>"
          end
        end

        # wiki links are like so: {{Another Page}}
        def process_wiki_links(str)
          str.gsub(WIKI_LINK_FMT) do |s|
            name, uri = $1, Framework::Controller::Uri.page($1)
            notextile do
              if Page.exists?(name)
                "<a href=\"#{uri}\">#{name}</a>"
              else
                "<span class=\"nonexistant\">#{name}<a href=\"#{uri}\">?</a></span>"
              end
            end
          end
        end

        # helper to wrap wrap block in notextile tags (block should return html string)
        def notextile
          str = yield
          "<notextile>#{str.to_s}</notextile>" if str && str.any?
        end

        # textile -> html filtering
        def textile_to_html(str)
          RedCloth.new(str).to_html
        end

        # auto-link web addresses in plain text
        def autolink(str)
          str.gsub(AUTO_LINK_RE) do
            all, a, b, c, d = $&, $1, $2, $3, $4
            if a =~ /<a\s/i # don't replace URL's that are already linked
              all
            else
              "#{a}<a href=\"#{ b == 'www.' ? 'http://www.' : b }#{c}\">#{b + c}</a>#{d}"
            end
          end
        end
      end
    end
  end

  # controllers definitions go here
  module Controllers

    VALID_PAGE_NAME_CHARS = '\w \+\%\-\.'
    PAGE_NAME = "([#{VALID_PAGE_NAME_CHARS}]+)"

    VALID_SEARCH_STRING_CHARS = '0-9a-zA-Z\+\%\`\~\!\^\*\(\)\_\-\[\]\{\}\\\|\'\"\.\<\>'
    SEARCH_STRING = "([#{VALID_SEARCH_STRING_CHARS}]+)"

    # reopen framework controller class to provide some app-specific logic
    class Framework::Controller
      # pass title and uri mappings into templates too
      alias :original_render :render
      def render(template, title, params={})
        common_params = { :title => title, :uri => Uri, :conf => CONF,
          :conflicts => Satellite::Models::Page.conflicts }
        original_render(template, params.merge!(common_params))
      end

      # uri mappings
      # TODO somehow generate these from routing table?
      class Uri
        class << self
          def page(name) "/page/#{escape(name)}" end
          def edit_page(name) "/page/#{escape(name)}/edit" end
          def rename_page(name) "/page/#{escape(name)}/rename" end
          def delete_page(name) "/page/#{escape(name)}/delete" end
          def resolve_conflict(name) "/page/#{escape(name)}/resolve" end
          def new_page() '/new' end
          def list() '/list' end
          def home() '/page/Home' end
          def search() '/search' end
        end
      end
    end

    class IndexController < controller '/'
      def get; redirect Uri.home; end
      def post; redirect Uri.home; end
    end

    class PageController < controller "/page/#{PAGE_NAME}", "/page/#{PAGE_NAME}/(edit|resolve)"
      def get(name, action='view')
        # load page
        begin
          page = Models::Page.load(name)
        rescue Db::FileNotFound
          page = nil
        end

        # do stuff
        case action
        when 'view'
          if page
            render 'show_page', page.name, :page => page
          else
            redirect Uri.edit_page(name)
          end
        when 'edit'
          page ||= Models::Page.new(name)
          render 'edit_page', "Editing #{page.name}", :page => page
        when 'resolve'
          if page
            render 'resolve_conflict_page', "Resolving #{page.name}", :page => page
          else
            redirect Uri.edit_page(name)
          end
        else
          raise RuntimeError.new("PageController does not support the '#{action}' action.")
        end
      end
  
      def post(name, action=nil)
        page = Models::Page.new(name, @input['content'])
        page.save
        redirect Uri.page(page.name)
      end
    end

    class NewPageController < controller '/new'
      def get
        render 'new_page', 'Add page', :page => Models::Page.new
      end
  
      def post
        page = Models::Page.new(@input['name'].strip, @input['content'])
        unless Models::Page.exists?(page.name)
          page.save
          redirect Uri.page(page.name)
        else
          render 'new_page', 'Add page', :page => page, :error => "A page named #{page.name} already exists"
        end
      end
    end
    
    class RenamePageController < controller "/page/#{PAGE_NAME}/rename"
      def get(name)
        page = Models::Page.load(name)
        render 'rename_page', "Renaming #{page.name}", :page => page
      end
      
      def post(name)
        page = Models::Page.rename(name, @input['new_name'].strip)
        redirect Uri.page(page.name)
      end
    end

    class DeletePageController < controller "/page/#{PAGE_NAME}/delete"
      def get(name)
        page = Models::Page.load(name)
        render 'delete_page', "Deleting #{page.name}", :page => page
      end
      
      def post(name)
        page = Models::Page.load(name)
        page.delete!
        redirect Uri.list
      end
    end

    class ListController < controller '/list'
      def get
        render 'list_pages', 'All pages', :pages => Models::Page.list
      end
    end

    class SearchController < controller '/search', "/search\\?query=#{SEARCH_STRING}"
      def get(query=nil)
        if query
          log :debug, "searched for: #{query}"
          results = Models::Page.search(query)
          render 'search', "Searched for: #{query}", :query => query, :results => results
        else
          render 'search', 'Search'
        end
      end
    end
    
    class UploadController < controller '/upload'
      def post
        log :debug, "upload: #{@upload}"
        save_file(@input['Filedata'][:tempfile], 'tmp/uploads/' + @input['Filedata'][:filename])
        respond "Thanks!"
      end
    end
  end

  class << self
    def start
      # kill the whole server if an unexpected exception is encounted in the sync
      Thread.abort_on_exception = true

      # spawn thread to sync content with master repository
      Thread.new do
        while true
          log :debug, "Synchronizing with master repository."

          begin
            Db.sync
          rescue Db::MergeConflict => e
            # TODO surface on front-end? already happens on page-load, though?
            log :warn, "Encountered conflicts during sync. The following files must be merged manually:" + 
              Db.conflicts.collect {|c| "  * #{c}" }.join("\n")
          rescue Db::ConnectionFailed
            log :warn, "Failed to connect to master repository during sync operation."
          end
          
          # sleep until next sync
          sleep CONF.sync_frequency
        end
      end
      
      # start server
      Framework::Server.new(CONF.server_ip, CONF.server_port, Controllers).start
    end
  end
end
