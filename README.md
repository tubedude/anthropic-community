# Anthropic Elixir API Wrapper

This unofficial Elixir wrapper provides a convenient way to interact with the [Anthropic API](https://docs.anthropic.com/claude/reference/getting-started-with-the-api), specifically designed to work with the [Claude LLM model](https://docs.anthropic.com/claude/docs/intro-to-claude). It includes modules for handling configuration, preparing requests, sending them to the API, and processing responses.

## Features

- Easy setup and configuration.
- Support for sending messages and receiving responses from the Claude LLM model.
- Error handling for both client and server-side issues.
- Customizable request parameters to tweak the behavior of the API.

## To dos:

- Add Streaming handling
- Add tool description
- Add telemetry

## Installation

The package can be installed
by adding `anthropic` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:anthropic, "~> 0.1.0"}
  ]
end
```

## Configuration
Add or create a config file to provide the `api_key` as in the example below.

```
# config/config.exs
import Config

config :anthropic,
  api_key: System.get_env("ANTHROPIC_API_KEY")
```

## Usage

```
{:ok, response, request} =
  Anthropic.new()
  |> Anthropic.add_system_message("You are a helpful assistant")
  |> Anthropic.add_user_message("Explain me monads in computer science. Be concise.")
  |> Anthropic.request_next_message()
```

Response will hold a map with the API response.
```
%{
  id: "msg_013Zva2CMHLNnXjNJJKqJ2EF",
  content: [
    %{type: "text", content: "Monads in computer science are a concept borrowed from category theory in mathematics, applied to abstract and manage complexity in functional programming. They provide a framework for chaining operations together step by step, where each step is processed in a context that can handle aspects like computations with side effects (e.g., state changes, I/O operations), errors, or asynchronous operations, without losing the purity of functional programming."}
  ],
  model: "claude-3-opus-20240229",
  role: "assistant",
  stop_reason: "end_turn",
  stop_sequence: null,
  type: "message",
  usage": {
    "input_tokens": 10,
    "output_tokens": 25
  }
}
```
But the conversation can continue:

```
request
|> Anthropic.add_user_message("Hold on right there! ELI5!")
|> Anthropic.request_next_message()

```


