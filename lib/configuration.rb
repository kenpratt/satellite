class Configuration
  # name of the wiki
  attr_accessor :app_name

  # IP and port to run local server on
  attr_accessor :server_ip
  attr_accessor :server_port

  # URI of master git repository for wiki content
  attr_accessor :master_repository_uri

  # user information to use for git content submissions
  attr_accessor :user_name
  attr_accessor :user_email

  # time in seconds to wait between attempts to sync with the master repository
  attr_accessor :sync_frequency

  # application paths
  attr_accessor :app_dir
  attr_accessor :conf_dir
  attr_accessor :template_dir
  attr_accessor :static_dir
  attr_accessor :log_dir

  # path of folder to store wiki app data in (this folder will be created)
  attr_accessor :data_dir

  # logging level (:fatal > :error > :warn > :info > :debug), log file name
  attr_accessor :log_level
  attr_accessor :log_file_name

  # automatically reload app when app files change? (for development)
  attr_accessor :auto_reload

  # turn exceptions into pretty html page
  attr_accessor :prettify_exceptions

  # maximum upload file size (in MB)
  attr_accessor :max_upload_filesize

  def initialize
    # defaults values
    self.app_name               = 'Satellite'
    self.server_ip              = '0.0.0.0'
    self.server_port            = 3000
    self.master_repository_uri  = ''
    self.user_name              = ''
    self.user_email             = ''
    self.sync_frequency         = 60
    self.app_dir                = File.join(File.dirname(File.expand_path(__FILE__)), '../')
    self.conf_dir               = File.join(app_dir, 'conf')
    self.template_dir           = File.join(app_dir, 'templates')
    self.static_dir             = File.join(app_dir, 'static')
    self.log_dir                = File.join(app_dir, 'log')
    self.data_dir               = File.join(app_dir, 'data')
    self.log_level              = :info
    self.log_file_name          = 'app.log'
    self.auto_reload            = false
    self.prettify_exceptions    = true
    self.max_upload_filesize    = 200
  end

  def load(env)
    config_file = File.join(conf_dir, "#{env}.rb")
    env = lambda { config = self; binding }
    eval(IO.read(config_file), env.call)
    self
  end

  def to_s
    [
      :app_name, :server_ip, :server_port, :master_repository_uri,
      :user_name, :user_email, :sync_frequency, :app_dir, :conf_dir,
      :template_dir, :static_dir, :log_dir, :data_dir, :log_level,
      :log_file_name, :auto_reload, :prettify_exceptions, 
      :max_upload_filesize
    ].collect do |c|
      sprintf "%12-s => %s", c.to_s, send(c).to_s
    end.join("\n")
  end

  class << self
    def load(env)
      config = Configuration.new
      config.load(env)
    end
  end
end
