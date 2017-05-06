# configuration for running on the rpi0
use Mix.Config

# tell logger to load a LoggerFileBackend processes
config :logger,
  backends: [{LoggerFileBackend, :info},
             {LoggerFileBackend, :error}]

# configuration for the {LoggerFileBackend, :error_log} backend
config :logger, :error_log,
  path: "/root/error.log",
  level: :error
config :logger, :info,
  path: "/root/info.log",
  level: :info
