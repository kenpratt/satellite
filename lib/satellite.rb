#!/bin/env ruby

# This is the main Satellite app. All business logic is contained here. 
# - configuration is in config.rb
# - controller and view framework is in framework.rb
# - "database" aka Git interface is in db.rb

%w{ config framework db rubygems metaid redcloth open-uri erubis }.each {|l| require l }

module Satellite

  # model definitions go here
  module Models

    # "Page" is a model representing a wiki page
    # Pages are saved locally in the filesystem, changes are committed to a local
    # Git repository which is mirrored to a master repository
    class Page
      include Comparable
    
      VALID_NAME_CHARS = '\w \!\@\#\$\%\^\&\(\)\-\_\+\=\[\]\{\}\,\.'
      WIKI_LINK_FMT = /\{\{([#{VALID_NAME_CHARS}]+)\}\}/
  
      PAGE_DIR = 'pages'
      PAGE_PATH = File.join(Conf::DATA_DIR, PAGE_DIR)
    
      # static methods
      class << self
        def list
          Dir[filepath('*')].collect {|s| s.sub(/^#{PAGE_PATH}\/(.+)\.textile$/, '\1') }.collect {|s| Page.new(s) }.sort
        end

        def load(name)
          if exists?(name)
            Page.new(name, open(filepath(name)).read)
          else
            nil
          end
        end

        def exists?(name)
          File.exists?(filepath(name))
        end
        
        def valid_name?(name)
          name =~ /^[#{VALID_NAME_CHARS}]+$/
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
        def filepath(name); File.join(PAGE_PATH, filename(name)); end
      end
  
      # instance methods
      attr_reader :name
      attr_writer :body

      def initialize(name='', body='')
        @name = name
        @body = body
        raise ArgumentError.new("Name is invalid: #{name}") if name.any? && !valid_name?
      end

      def body(format=nil)
        case format
        when :html
          to_html
        else
          @body
        end
      end
  
      def save
        begin
          save_file(@body, filepath)
          Db.save(local_filepath, "Satellite: saving #{name}")
        rescue Db::ContentNotModified
          log "Didn't need to save #{name}"
        end
      end
  
      def valid_name?
        Page.valid_name?(name)
      end
      
      def rename(new_name)
        raise ArgumentError.new("Name is invalid: #{new_name}") unless new_name.any? && Page.valid_name?(new_name)
        Db.mv(local_filepath, Page.local_filepath(new_name), "Satellite: renaming #{name} to #{new_name}")
        @name = new_name
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
        str = @body
      
        # wiki linking
        str = str.gsub(WIKI_LINK_FMT) do |s|
          name, uri = $1, Framework::Controller::Uri.page($1)
          notextile do
            if Page.exists?(name)
              "<a href=\"#{uri}\">#{name}</a>"
            else
              "<span class=\"nonexistant\">#{name}<a href=\"#{uri}\">?</a></span>"
            end 
          end
        end
      
        # textile -> html filtering
        RedCloth.new(str).to_html
      end
  
      def filename; Page.filename(name); end
      def local_filepath; Page.local_filepath(name); end
      def filepath; Page.filepath(name); end
    
      # helper to wrap wrap block in notextile tags (block should return html string)
      def notextile
        str = yield
        "<notextile>#{str.to_s}</notextile>" if str && str.any?
      end
    end
  end

  # controllers definitions go here
  module Controllers
    
    VALID_PAGE_NAME_CHARS = '\w \+\%\-\.'
    PAGE_NAME = "([#{VALID_PAGE_NAME_CHARS}]+)"

    # reopen controller class to provide some app-specific logic
    class Framework::Controller
      
      # pass title and uri mappings into templates too
      alias :original_render :render
      def render(template, title, params={})
        original_render(template, params.merge!({ :title => title, :uri => Uri }))
      end
  
      # uri mappings
      # TODO somehow generate these from routing table?
      class Uri
        class << self
          def page(name) "/page/#{escape(name)}" end
          def edit_page(name) "/page/#{escape(name)}/edit" end
          def rename_page(name) "/page/#{escape(name)}/rename" end
          def new_page() '/new' end
          def list() '/list' end
          def home() '/page/Home' end
        end
      end
    end
    
    class IndexController < controller '/'
      def get; redirect Uri.home; end
      def post; redirect Uri.home; end
    end

    class PageController < controller "/page/#{PAGE_NAME}", "/page/#{PAGE_NAME}/(edit)"
      def get(name, action='view')
        page = Models::Page.load(name)
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

    class ListController < controller '/list'
      def get
        render 'list_pages', 'All pages', :pages => Models::Page.list
      end
    end
  end

  class << self
    def start
      Framework::Server.new(Conf::SERVER_IP, Conf::SERVER_PORT, Controllers).start
    end
  end
end
