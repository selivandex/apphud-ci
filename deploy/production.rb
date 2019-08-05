# frozen_string_literal: true

server '138.201.150.209', roles: %i[web app db worker], primary: true

set :branch, 'master'
set :keep_releases, 5

set :puma_role, :app
set :puma_threads,    [2, 4]
set :puma_workers,    2

set :sidekiq_env, :production
set :sidekiq_config, "/home/#{fetch(:user)}/#{fetch(:application)}/current/config/sidekiq.yml"
