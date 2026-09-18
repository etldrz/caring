import Config

config :experiment_manager, :logger,
[
  {:handler, :exp_log, ExpLog, config=%{}}
]
