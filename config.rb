class Conf
  # name of the wiki
  APPNAME     = 'Satellite'

  # IP and port to run local server on
  SERVER_IP   = '0.0.0.0'
  SERVER_PORT = 3000
  
  # path of folder to store wiki page contents in (this folder will be created)
  DATA_DIR    = 'content/'
  
  # URI of master git repository for wiki content
  ORIGIN_URI  = 'git+ssh://mueller/git/wiki.kenpratt.net'
  
  # user information to use for git content submissions
  USER_NAME   = 'Ken Pratt'
  USER_EMAIL  = 'ken@kenpratt.net'
end
