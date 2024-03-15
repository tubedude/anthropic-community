# Anthropic Elixir API Wrapper
This unofficial Elixir wrapper provides a convenient way to interact with the [Anthropic API](https://docs.anthropic.com/claude/reference/getting-started-with-the-api), specifically designed to work with the [Claude LLM model](https://docs.anthropic.com/claude/docs/intro-to-claude). It includes modules for handling configuration, preparing requests, sending them to the API, and processing responses.

## Features
- Easy setup and configuration.
- Support for registering and invoking tools.
- Support for sending messages and receiving responses from the Claude LLM model.
- Error handling for both client and server-side issues.
- Customizable request parameters to tweak the behavior of the API.

## To-dos
- Add streaming handling
- Allow for Tool do define different models.

## Installation
The package can be installed by adding `anthropic` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:anthropic, "~> 0.4.0", hex: :anthropic_community}
  ]
end
```

## Configuration
Add or create a config file to provide the `api_key` as in the example below. Or pass an `:api_key` as option on `Anthropic.new(api_key: "key")`

```elixir
# config/config.exs
import Config

config :anthropic,
  api_key: System.get_env("ANTHROPIC_API_KEY")
```

## Usage
### Basic Conversation
```elixir
{:ok, response, request} =
  Anthropic.new()
  |> Anthropic.add_system_message("You are a helpful assistant")
  |> Anthropic.add_user_message("Explain monads in computer science. Be concise.")
  |> Anthropic.request_next_message()
```

The `response` will hold a map with the API response.

```elixir
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
  usage: %{
    "input_tokens" => 10,
    "output_tokens" => 25
  }
}
```

The conversation can continue:

```elixir
request
|> Anthropic.add_user_message("Hold on right there! ELI5!")
|> Anthropic.request_next_message()
```

### Registering and Invoking Tools
You can register tools that the AI can use to perform specific tasks. Here's an example:

```elixir
defmodule MyApp.WeatherTool do
  @behaviour Anthropic.Tool.ToolBehaviour


  @impl true
  def description do
    """
    Tool description to explain AI how and when to use it
    """
  end

  @impl true
  def parameters do
    [
      {:location, :string, "The city and state of the location you need the weather"}
    ]
  end

  @impl true
  def invoke(location: location) do
    # Implement the tool's functionality here
    # ...
    # and return a string
  end
end

{:ok, response, request} =
  Anthropic.new()
  |> Anthropic.register_tool(MyApp.WeatherTool)
  |> Anthropic.add_user_message("Use the MyApp.WeatherTool to perform a task.")
  |> Anthropic.request_next_message()
  |> Anthropic.process_invocations()
```
