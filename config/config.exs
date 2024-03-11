import Config

config :anthropic,
  api_key: System.get_env("ANTHROPIC_API_KEY")
