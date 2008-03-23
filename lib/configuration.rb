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

  # application paths
  attr_accessor :app_dir
  attr_accessor :conf_dir
  attr_accessor :template_dir

  # path of folder to store wiki app data in (this folder will be created)
  attr_accessor :data_dir
  
  def initialize
    # defaults values
    self.app_name               = 'Satellite'
    self.server_ip              = '0.0.0.0'
    self.server_port            = 3000
    self.master_repository_uri  = ''
    self.user_name              = ''
    self.user_email             = ''
    self.app_dir                = File.join(File.dirname(File.expand_path(__FILE__)), '../')
    self.conf_dir               = File.join(app_dir, 'conf')
    self.template_dir           = File.join(app_dir, 'templates')
    self.data_dir               = File.join(app_dir, 'data')
  end
  
  def load(env)
    config_file = File.join(conf_dir, "#{env}.rb")
    env = lambda { config = self; binding }
    eval(IO.read(config_file), env.call)
    self
  end

  def to_s
    [ :app_name, :server_ip, :server_port, :master_repository_uri, :user_name, 
      :user_email, :app_dir, :conf_dir, :template_dir, :data_dir ].collect do |c|
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
