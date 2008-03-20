class Conf
  # name of the wiki
  APP_NAME      = 'Satellite'

  # IP and port to run local server on
  SERVER_IP     = '0.0.0.0'
  SERVER_PORT   = 3000
    
  # URI of master git repository for wiki content
  #ORIGIN_URI    =  'git+ssh://mueller/git/wiki.kenpratt.net'
  ORIGIN_URI    = '~/tmp/satellite_master_repo'
  
  # user information to use for git content submissions
  USER_NAME     = 'Ken Pratt'
  USER_EMAIL    = 'ken@kenpratt.net'
  
  # paths
  APP_DIR       = File.join(File.dirname(File.expand_path(__FILE__)), '../')
  TEMPLATE_DIR  = File.join(APP_DIR, 'templates')

  # path of folder to store wiki app content in (this folder will be created)
  DATA_DIR      = File.join(APP_DIR, 'content')
end
