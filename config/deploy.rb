# config valid only for current version of Capistrano
lock "3.8.1"

set :application, "redmineApp"
set :repo_url, "git@github.com:Hooz/redmine.git"
set :deploy_via, :export

set :linked_files,
  %w{config/database.yml config/environments/production.rb config/secrets.yml config/initializers/secret_token.rb 
    config/configuration.yml}
set :linked_dirs, %w{log}

namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "mkdir #{shared_path}/tmp/pids -p"
    end
  end

  before :start, :make_dirs
end

namespace :deploy do
desc 'Initial Deploy'
  task :initial do
    on roles(:app) do
      before 'deploy:restart', 'puma:start'
      invoke 'deploy'
    end
  end

  desc 'Restart application'
  task :restart do
    on roles(:app), in: :sequence, wait: 5 do
      invoke 'puma:restart'
    end
  end

  after  :finishing,    :compile_assets
  after  :finishing,    :cleanup
end

# namespace :assets do
#   desc "assets:precompile"
#   task :precompile do
#   	on primary(:app) do
#       within release_path do
#         with rails_env: fetch(:rails_env) do
#           execute :bundle, "exec rake assets:precompile"
#         end
#       end
#     end
#   end
# end