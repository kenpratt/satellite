# This is the "database", which entails a local git repository to store pages
# in as well as a master repository to pull changes from and push changes to.

%w{ configuration rubygems fileutils }.each {|l| require l }

require 'git'

def quote(s)
  "'#{s}'"
end

# wrapper for ruby/git bridge
class GitDb
  inject :conf
  inject :logger

  class ConfigurationError < RuntimeError; end
  class FileNotFound < RuntimeError; end
  class ContentNotModified < RuntimeError; end
  class MergeConflict < RuntimeError; end
  class ConnectionFailed < RuntimeError; end

  def initialize
    @repo = nil
  end

  def sync
    repo.pull
    repo.push
  end

  def push
    repo.push
  end

  def conflicts
    # repo.ls_unmerged_files.keys
    repo.lib.unmerged
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
    repo.grep(str, nil, :ignore_case => true).each {|k, v| out[k.sub(/^.+:/, '')] = v }
    out
  end

  def repack
    repo.repack
  end

  def obliterate!
    if @repo
      @repo.obliterate!
      @repo = nil
    else
      begin
        open
        @repo.obliterate!
        @repo = nil
      rescue ArgumentError => e
        # repo doesn't exist yet -- nothing to obliterate
      end
    end
  end

private

  def repo
    @repo ||= open_or_clone
  end

  def open_or_clone
    begin
      open
    rescue ArgumentError => e
      # repo doesn't exist yet
      clone
    end
    @repo
  end

  def open
    @repo = Repo.new(Git.open(conf.data_dir))
    @repo.update_config
  end

  def clone
    # create data directory
    FileUtils.mkdir_p(conf.data_dir)
    FileUtils.cd(conf.data_dir)

    # create git repo
    @repo = Repo.new(Git.init)

    # set user params
    @repo.config('user.name', conf.user_name)
    @repo.config('user.email', conf.user_email)

    # convert line endings to LF on commit
    @repo.config('core.autocrlf', 'input')

    # add origin
    @repo.add_remote('origin', conf.master_repository_uri)

    # pull down initial content
    @repo.pull
  end

  # private inner class that encapsulates Git operations
  class Repo
    inject :conf
    inject :logger

    # instance methods
    def initialize(git_instance)
      @git = git_instance
    end

    def update_config
      {
        'user.name' => conf.user_name,
        'user.email' => conf.user_email,
        'remote.origin.url' => conf.master_repository_uri
      }.each do |k, v|
        if (old = @git.config(k)) != v
          logger.info "Updating GitDB configuration: Changing #{k} from '#{old}' to '#{v}'"
          @git.config(k, v)
        end
      end
    end

    def push
      begin
        @git.push
      rescue Git::GitExecuteError => e
        case e.message
        when /src refspec master does not match any/
          # no local commits yet, we can safely ignore it
        when /The remote end hung up unexpectedly/
          # no internet or bad host address
          raise ConnectionFailed.new(e.message)
        else
          puts "Unexpected error in GitDb::Repo.push: \"#{e.message}\""
          raise e
        end
      end
    end

    def pull
      begin
        # the documentation claims that the second argument should just be
        # 'master', but that doesn't seem to work
        # @git.pull('origin', 'master', 'pulling from remote repository')
        @git.fetch('origin')
        @git.merge('origin/master', 'pulling from remote repository')
      rescue Git::GitExecuteError => e
        case e.message
        when /no matching remote head/, /Needed a single revision/
          # a 'no matching remote head' error is returned when the remote repo
          # exists but is currently empty, so we can safely ignore it
        when /not something we can merge/
          # new repo with no commits -- we can safely ignore it
        when /unable to chdir or not a git archive/
          # remote repo doesn't exist!
          raise ConfigurationError.new("It appears that the remote repository " +
            "(#{conf.master_repository_uri}) does not exist. Please try running " +
            "the 'create_master_repo' script to create the repository.")
        when /Merge conflict/, /You are in the middle of a conflicted merge/
          # someone committed a conflicting change to the remote repository
          raise MergeConflict.new(e.message)
        when /The remote end hung up unexpectedly/
          # no internet or bad host address
          raise ConnectionFailed.new(e.message)
        else
          puts "Unexpected error in GitDb::Repo.pull: \"#{e.message}\""
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
          puts "Error in GitDb::Repo.add: Need to delete #{$1}"
          raise e
        else
          puts "Unexpected error in GitDb::Repo.add: \"#{e.message}\""
          raise e
        end
      end
    end

    def mv(from, to)
      begin
        FileUtils.mv(File.join(conf.data_dir, from), File.join(conf.data_dir, to))
      rescue Errno::ENOENT => e
        case e.message
        when /No such file or directory/
          raise FileNotFound.new("File #{File.join(conf.data_dir, from)} does not exist")
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

    def obliterate!
      FileUtils.cd(conf.app_dir)
      FileUtils.rm_rf(conf.data_dir)
    end

    def method_missing(name, *args)
      if @git.respond_to?(name)
        @git.send(name, *args)
      else
        raise NameError.new("Git gem doesn't respond to #{name}(#{args.map(&:inspect).join(', ')})")
      end
    end
  end
end
