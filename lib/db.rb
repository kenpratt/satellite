# This is the "database", which entails a local git repository to store pages
# in as well as a master repository to pull changes from and push changes to.

%w{ configuration rubygems fileutils git }.each {|l| require l }

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

# monkey-patch ruby/git bridge to allow case-insensitive greps
Git::Base.class_eval do
  def grep(query, opts = {})
    self.object('HEAD').grep(query, nil, opts)
  end
end

def quote(s)
  "'#{s}'"
end

# wrapper for ruby/git bridge
module Db

  class ConfigurationError < RuntimeError; end
  class FileNotFound < RuntimeError; end
  class ContentNotModified < RuntimeError; end
  class MergeConflict < RuntimeError; end
  class ConnectionFailed < RuntimeError; end

  class << self

    def sync
      repo.pull
      repo.push
    end

    def conflicts
      repo.ls_unmerged_files.keys
    end

    def save(file, message)
      repo.add(quote(file))
      repo.commit(message)
    end

    def mv(from, to, message)
      repo.mv(from, to)
      repo.commit(message)
    end

    def rm(file, message)
      repo.remove(quote(file))
      repo.commit(message)
    end

    def search(str)
      out = {}
      repo.grep(str, :ignore_case => true).each {|k, v| out[k.sub(/^.+:/, '')] = v }
      out
    end
  end

  private

  class << self
    def repo
      @@repo ||= open_or_create
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
        r = Repo.new(Git.open(CONF.data_dir))
        r.update_config
        r
      end

      def clone
        # create data directory
        FileUtils.mkdir_p(CONF.data_dir)
        FileUtils.cd(CONF.data_dir)

        # create git repo
        r = Repo.new(Git.init)

        # set user params
        r.config('user.name', CONF.user_name)
        r.config('user.email', CONF.user_email)

        # convert line endings to LF on commit
        r.config('core.autocrlf', 'input')

        # add origin
        r.add_remote('origin', CONF.master_repository_uri)

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
        'user.name' => CONF.user_name,
        'user.email' => CONF.user_email,
        'remote.origin.url' => CONF.master_repository_uri
      }.each do |k, v|
        if (old = @git.config(k)) != v
          log :info, "Updating configuration: changing #{k} from '#{old}' to '#{v}'"
          @git.config(k, v)
        end
      end
    end

    def push
      begin
        @git.push
      rescue Git::GitExecuteError => e
        case e.message
        when /The remote end hung up unexpectedly/
          # no internet or bad host address
          raise ConnectionFailed.new
        else
          puts "Unexpected error in Db.push: \"#{e.message}\""
          raise e
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
        when /no matching remote head/, /Needed a single revision/
          # a 'no matching remote head' error is returned when the remote repo
          # exists but is currently empty, so we can safely ignore it
        when /unable to chdir or not a git archive/
          # remote repo doesn't exist!
          raise ConfigurationError.new("It appears that the remote repository " +
            "(#{CONF.master_repository_uri}) does not exist. Please try running " +
            "the 'create_master_repo' script to create the repository.")
        when /Merge conflict/, /You are in the middle of a conflicted merge/
          # someone committed a conflicting change to the remote repository
          raise MergeConflict.new(e.message)
        when /The remote end hung up unexpectedly/
          # no internet or bad host address
          raise ConnectionFailed.new
        else
          puts "Unexpected error in Db.pull: \"#{e.message}\""
          raise e
        end
      end
    end

    def add(file)
      begin
        @git.add(file)
      rescue Git::GitExecuteError => e
        case e.message
        when /unable to create '(.+index\.lock)'/
          # race condition, deleting the lock file should fix it
          puts "Error in Db.add: Need to delete #{$1}"
          raise e
        else
          puts "Unexpected error in Db.add: \"#{e.message}\""
          raise e
        end
      end
    end

    def mv(from, to)
      begin
        FileUtils.mv(File.join(CONF.data_dir, from), File.join(CONF.data_dir, to))
      rescue Errno::ENOENT => e
        case e.message
        when /No such file or directory/
          raise FileNotFound.new("File #{File.join(CONF.data_dir, from)} does not exist")
        else
          raise e
        end
      end
      @git.add(quote(to))
      @git.remove(quote(from))
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
