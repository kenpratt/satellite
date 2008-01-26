# This is the "database", which entails a local git repository to store pages 
# in as well as a master repository to pull changes from and push changes to.

%w{ config rubygems fileutils git }.each {|l| require l }

module Db
    
  def self.sync
    r = open_or_create
    r.pull
    #r.push
  end
  
  def self.save(file, message)
    r = open_or_create
    r.add(file)
    r.commit(message)
  end

  private
  
  def self.open_or_create
    begin
      Repo.open
    rescue ArgumentError => e
      # repo doesn't exist yet
      Repo.clone
    end
  end
  
  class Repo
    def initialize(git_instance)
      @git = git_instance
    end
    
    def self.open
      Repo.new(Git.open(Conf::DATA_DIR))
    end
    
    def self.clone
      # create data directory
      FileUtils.mkdir_p(Conf::DATA_DIR)
      FileUtils.cd(Conf::DATA_DIR)
       
      # create git repo
      r = Repo.new(Git.init)
      
      # set user params
      r.config('user.name', Conf::USER_NAME)
      r.config('user.email', Conf::USER_EMAIL)

      # add origin
      r.add_remote('origin', Conf::ORIGIN_URI)

      # pull down initial content
      r.pull
      
      # return repository instance
      return r
    end
    
    def pull
      begin
        @git.pull
      rescue Git::GitExecuteError => e
        # this error is returned when repo exists but is empty, so ignore it
        raise e unless e.message.include?('no matching remote head')
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

