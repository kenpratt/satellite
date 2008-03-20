#!/usr/bin/env ruby
#
# Fix line endings on content pages and add blank line at the end
#

%w{ config lib }.each {|l| $LOAD_PATH.unshift("#{File.expand_path(File.dirname(__FILE__))}/../#{l}") }

require 'config'

PAGE_PATH = File.join(Conf::DATA_DIR, 'pages')

Dir[File.join(PAGE_PATH, "*.textile")].each do |file|
  s = open(file, 'r').read
  s.gsub!(/\r\n/, "\n")
  s += "\n" unless s[-1..-1] == "\n"
  open(file, 'w') {|f| f << s }
end
