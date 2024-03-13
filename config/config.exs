import Config

config :anthropic,
  api_key: System.get_env("ANTHROPIC_API_KEY"),
  model: "claude-3-haiku-20240307"
