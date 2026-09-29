import Config

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  time_format: "%H:%M:%S.%f"
