# test configuration

# URI of master git repository for wiki content
config.master_repository_uri = File.join(config.app_dir, 'tmp/test_master_repo')

# local data directory
config.data_dir = File.join(config.app_dir, 'tmp/test_local_data')

# user information to use for git content submissions
config.user_name = 'Ken Pratt'
config.user_email = 'ken@kenpratt.net'

# logging level (:error, :warn, :info, :debug)
config.log_level = :debug
