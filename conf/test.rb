# test configuration

# local master git repository for wiki content
config.master_repository_uri = File.join(config.app_dir, 'tmp/test_master_repo')

# test data directory
config.data_dir = File.join(config.app_dir, 'tmp/test_local_data')

# user information to use for git content submissions
config.user_name = 'Ken Pratt'
config.user_email = 'ken@kenpratt.net'

# logger
config.log_file_name = 'test.log'
config.log_level = :debug

# don't prettify exceptions
config.prettify_exceptions = false
