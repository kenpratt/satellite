require 'rubygems'
require 'redcloth'
require 'coderay'

# all the wiki markup stuff should go in here
module Satellite
  class WikiMarkup
    inject :urimap

    WIKI_LINK_FMT = /\{\{([#{VALID_FILENAME_CHARS}]+)\}\}/
    UPLOAD_LINK_FMT = /\{\{upload:([#{VALID_FILENAME_CHARS}]+)\}\}/
    IMAGE_LINK_FMT = /\{\{image:([#{VALID_FILENAME_CHARS}]+)\}\}/

    AUTO_LINK_RE = %r{
                    (                          # leading text
                      <\w+.*?>|                # leading HTML tag, or
                      [^=!:\'\"/]|             # leading punctuation, or
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
                   }x

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
        # add surrounding newlines to avoid garbling during textile parsing
        "\n\n<notextile>#{code}</notextile>\n\n"
      end
    end

    # wiki links are like so: {{Another Page}}
    # uploads are like: {{upload:foo.ext}}
    def process_wiki_links(str)
      str.gsub(UPLOAD_LINK_FMT) do |s|
        begin
          upload = Satellite::Models::Upload.new($1)
        rescue GitDb::FileNotFound
          upload = nil
        end
        notextile do
          if upload
            box(:upload, upload)
          else
            "<span class=\"nonexistent\">#{$1}</span>"
          end
        end
      end.gsub(IMAGE_LINK_FMT) do |s|
        begin
          upload = Satellite::Models::Upload.new($1)
        rescue GitDb::FileNotFound
          upload = nil
        end
        notextile do
          if upload
            box(:image, upload)
          else
            "<span class=\"nonexistent\">#{$1}</span>"
          end
        end
      end.gsub(WIKI_LINK_FMT) do |s|
        name, uri = $1, urimap.page($1)
        notextile do
          if Satellite::Models::Page.new(name).exists?
            "<a href=\"#{uri}\">#{name}</a>"
          else
            "<span class=\"nonexistent\">#{name}<a href=\"#{uri}\">?</a></span>"
          end
        end
      end
    end

    def box(type, upload)
      uri_upload = urimap.upload(upload.name)
      uri_rename = urimap.rename(upload)
      uri_delete = urimap.delete(upload)
      out = ""
      out << "<div class=\"#{type}-box\">"
      out << "<a href=\"#{uri_upload}\"><img src=\"#{uri_upload}\" /></a>" if type == :image
      out << "<span class=\"inner\">"
      out << "<a class=\"upload\" href=\"#{uri_upload}\">#{upload.name}</a> "
      out << "<a class=\"rename\" href=\"#{uri_rename}\"><span>Rename</span></a>"
      out << "<a class=\"delete\" href=\"#{uri_delete}\"><span>Delete</span></a>"
      out << "</span>"
      out << "</div>"
      out
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
