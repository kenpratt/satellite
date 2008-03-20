# This is the "database", which entails a local git repository to store pages 
# in as well as a master repository to pull changes from and push changes to.

%w{ config rubygems fileutils git }.each {|l| require l }

# monkey-patch ruby/git bridge to allow listing of unmerged files
Git::Lib.class_eval do
  def ls_files(opts=nil)
    hsh = {}
    command_lines('ls-files', opts || ['--stage']).each do |line|
      (info, file) = line.split("\t")
      (mode, sha, stage) = info.split
      hsh[file] = {:path => file, :mode_index => mode, :sha_index => sha, :stage => stage}
    end
    hsh
  end
end
Git::Base.class_eval do
  def ls_files(opts=nil)
    self.lib.ls_files(opts)
  end
  def ls_unmerged_files
    ls_files("--unmerged")
  end
end

# wrapper for ruby/git bridge
module Db
  
  class ContentNotModified < RuntimeError; end
  class ConfigurationError < RuntimeError; end
  class MergeConflict < RuntimeError; end
  
  class << self

    def sync
      r = open_or_create
      r.pull
      r.push
    end
    
    def conflicts
      r = open_or_create
      r.ls_unmerged_files.keys
    end

    def save(file, message)
      r = open_or_create
      r.add(quote(file))
      r.commit(message)
    end

    def mv(from, to, message)
      r = open_or_create
      r.mv(quote(from), quote(to))
      r.commit(message)
    end
    
    def rm(file, message)
      r = open_or_create
      r.remove(quote(file))
      r.commit(message)
    end
  end

  private
  
  class << self
    def quote(s)
      "'#{s}'"
    end
  
    def open_or_create
      begin
        Repo.open
      rescue ArgumentError => e
        # repo doesn't exist yet
        Repo.clone
      end
    end
  end
  
  # private inner class that encapsulates Git operations
  class Repo

    # static methods
    class << self
      def open
        r = Repo.new(Git.open(Conf::DATA_DIR))
        r.update_config
        r
      end

      def clone
        # create data directory
        FileUtils.mkdir_p(Conf::DATA_DIR)
        FileUtils.cd(Conf::DATA_DIR)

        # create git repo
        r = Repo.new(Git.init)

        # set user params
        r.config('user.name', Conf::USER_NAME)
        r.config('user.email', Conf::USER_EMAIL)

        # convert line endings to LF on commit
        r.config('core.autocrlf', 'input')

        # add origin
        r.add_remote('origin', Conf::ORIGIN_URI)

        # pull down initial content
        r.pull

        # return repository instance
        return r
      end
    end

    # instance methods
    def initialize(git_instance)
      @git = git_instance
    end
    
    def update_config
      { 
        'user.name' => Conf::USER_NAME,
        'user.email' => Conf::USER_EMAIL,
        'remote.origin.url' => Conf::ORIGIN_URI
      }.each do |k, v|
        if (old = @git.config(k)) != v
          puts "updating configuration: changing #{k} from '#{old}' to '#{v}'"
          @git.config(k, v)
        end
      end
    end
    
    def pull
      begin
        # the documentation claims that the second argument should just be 
        # 'master', but that doesn't seem to work
        @git.pull('origin', 'origin/master', 'pulling from remote repository')
      rescue Git::GitExecuteError => e
        case e.message
        when /no matching remote head/
          # a 'no matching remote head' error is returned when the remote repo
          # exists but is currently empty, so we can safely ignore it
        when /unable to chdir or not a git archive/
          # remote repo doesn't exist!
          raise ConfigurationError.new("It appears that the remote repository " +
            "(#{Conf::ORIGIN_URI}) does not exist. Please try running the " +
            "'create_master_repo' script to create the repository.")
        when /Merge conflict/, /You are in the middle of a conflicted merge/
          # someone committed a conflicting change to the remote repository
          raise MergeConflict.new(e.message)
        else
          raise e
        end
      end
    end
    
    def add(file)
      @git.add(file)
    end
    
    def mv(from, to)
      FileUtils.mv(File.join(Conf::DATA_DIR, from), File.join(Conf::DATA_DIR, to))
      @git.add(to)
      @git.remove(from)
    end
    
    def commit(msg)
      begin
        @git.commit(msg)
      rescue Git::GitExecuteError => e
        case e.message
        when /nothing to commit/
          raise ContentNotModified
        else
          raise e
        end
      end
    end
    
    def method_missing(name, *args)
      if @git.respond_to?(name)
        @git.send(name, *args)
      else
        raise NameError
      end
    end
  end
end
