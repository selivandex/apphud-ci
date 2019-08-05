# frozen_string_literal: true

lock '3.11.0'

set :stages, %w[staging production]
set :default_stage, 'production'

set :repo_url, 'git@github.com:softeamco/apphud.git'
set :application, 'apphud'

set :user, 'apphud'

set :rbenv_path, "/home/#{fetch(:user)}/.rbenv"
set :rbenv_ruby, '2.6.0'

# Don"t change these unless you know what you"re doing
set :pty,             false
set :use_sudo,        false
set :stage,           :production
set :deploy_via,      :remote_cache
set :deploy_to,       "/home/#{fetch(:user)}/#{fetch(:application)}"
set :puma_bind,       "unix://#{shared_path}/tmp/sockets/#{fetch(:application)}-puma.sock"
set :puma_state,      "#{shared_path}/tmp/pids/puma.state"
set :puma_pid,        "#{shared_path}/tmp/pids/puma.pid"
set :puma_access_log, "#{release_path}/log/puma.error.log"
set :puma_error_log,  "#{release_path}/log/puma.access.log"
set :ssh_options,     forward_agent: true, user: fetch(:user)
set :puma_preload_app, true
set :puma_worker_timeout, nil
set :puma_init_active_record, false # Change to false when not using ActiveRecord

# slack
# set :slack_url, ''
# set :slack_channel, ['#notifications']
# set :slack_username, 'Capistrano'

## Linked Files & Directories (Default None):
set :linked_dirs, %w[log public/uploads public/system config/keys public/packs node_modules]

before 'deploy:assets:precompile', 'deploy:yarn_install'
namespace :deploy do
  desc 'Run rake yarn install'
  task :yarn_install do
    on roles(:web) do
      within release_path do
        execute("cd #{release_path} && yarn install --silent --no-progress --no-audit --no-optional")
      end
    end
  end
end

namespace :puma do
  desc 'Create Directories for Puma Pids and Socket'
  task :make_dirs do
    on roles(:app, :worker, :stager) do
      execute "mkdir #{shared_path}/tmp/sockets -p"
      execute "mkdir #{shared_path}/tmp/pids -p"
    end
  end

  before :start, :make_dirs
end

namespace :sidekiqui do
  desc 'Start Sidekiq UI'
  task :start do
    on roles(:worker) do
      puts 'Start Sidekiq UI'
      execute("cd #{deploy_to}/current/sidekiq; /home/#{fetch(:user)}/.rbenv/bin/rbenv exec bundle exec puma -d -b \
        unix://#{deploy_to}/shared/tmp/sockets/sidekiqui-puma.sock --pidfile \
        #{deploy_to}/shared/tmp/pids/sidekiqui.pid")
    end
  end

  desc 'Stop Sidekiq UI'
  task :stop do
    on roles(:worker) do
      puts 'Stop Sidekiq UI'
      execute("cd #{deploy_to};if [ -f shared/tmp/pids/sidekiqui.pid ] && [ -e \
        /proc/$(cat shared/tmp/pids/sidekiqui.pid) ]; then kill -9 `cat shared/tmp/pids/sidekiqui.pid`; fi")
    end
  end

  desc 'Restart Sidekiq UI'
  task :restart do
    on roles(:worker) do
      invoke 'sidekiqui:stop'
      invoke 'sidekiqui:start'
    end
  end
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

  # before :starting,   'chrome:kill_all'
  after  :finishing,  :compile_assets
  after  :finishing,  :cleanup
  after  :finishing,  'currencies:import'
end

# ps aux | grep puma    # Get puma pid
# kill -s SIGUSR2 pid   # Restart puma
# kill -s SIGTERM pid   # Stop puma
