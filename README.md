# Anthropic Elixir API Client

An unofficial Elixir client for the [Anthropic API](https://docs.anthropic.com/claude/reference/getting-started-with-the-api), built around the same shape as Anthropic's official SDKs: an explicit `Client` struct, resource modules (`Messages`, `Models`, `Batches`), typed content blocks, native tool use, streaming, and automatic retries.

## Features

- **Typed content blocks** — `Text`, `ToolUse`, `ToolResult`, `Thinking`, `RedactedThinking`, and `Image` structs instead of raw maps.
- **Native tool use** — the real `tool_use`/`tool_result` protocol, with `Anthropic.ToolRunner` driving the full agentic loop for you.
- **Streaming** — `Anthropic.Messages.stream/2` returns a lazy `Stream` of typed SSE events, plus a convenience to fold it into a final message.
- **Automatic retries** — exponential backoff with jitter on `429`/`5xx`, honoring `retry-after`.
- **Unified errors** — one `Anthropic.Error` struct/exception mirroring the API's error taxonomy, with `!` bang variants that raise.
- **Models and Batches resources**, in addition to Messages.

## Installation

```elixir
def deps do
  [
    {:anthropic, "~> 0.5", hex: :anthropic_community}
  ]
end
```

## Configuration

Build a `Client` explicitly and pass it to every call:

```elixir
client = Anthropic.Client.new(api_key: System.fetch_env!("ANTHROPIC_API_KEY"))
```

`api_key` and `base_url` also fall back to `Application.get_env(:anthropic, ...)` and then to `ANTHROPIC_API_KEY`/`ANTHROPIC_BASE_URL` environment variables if not passed explicitly:

```elixir
# config/config.exs
import Config

config :anthropic, api_key: System.get_env("ANTHROPIC_API_KEY")
```

Other `Client` options: `base_url`, `api_version`, `max_retries` (default `2`), `timeout` (default `600_000` ms), `default_model`, `default_headers`.

## Usage

### Basic conversation

```elixir
{:ok, message} =
  Anthropic.Messages.create(client,
    model: "claude-opus-4-8",
    max_tokens: 1024,
    messages: [%{role: "user", content: "Explain monads in computer science. Be concise."}]
  )

message.content
#=> [%Anthropic.Messages.Content.Text{text: "Monads are..."}]

message.stop_reason
#=> "end_turn"
```

Use `Anthropic.Messages.create!/2` for a bang variant that returns the message directly and raises `Anthropic.Error` on failure.

### Streaming

```elixir
client
|> Anthropic.Messages.stream(model: "claude-opus-4-8", max_tokens: 1024,
     messages: [%{role: "user", content: "Write a haiku about Elixir"}])
|> Stream.each(fn
  %Anthropic.Messages.StreamEvent.ContentBlockDelta{delta: %{"type" => "text_delta", "text" => text}} ->
    IO.write(text)

  _other ->
    :ok
end)
|> Stream.run()
```

Or fold the stream into a final `Message`, equivalent to `create/2`:

```elixir
{:ok, message} =
  client
  |> Anthropic.Messages.stream(model: "claude-opus-4-8", max_tokens: 1024,
       messages: [%{role: "user", content: "Write a haiku about Elixir"}])
  |> Anthropic.Messages.stream_to_message()
```

### Tool use

Define a tool with a JSON Schema `input_schema`:

```elixir
defmodule MyApp.WeatherTool do
  use Anthropic.Tools

  @impl true
  def name, do: "get_weather"

  @impl true
  def description, do: "Get the current weather for a given city."

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{
        "location" => %{"type" => "string", "description" => "City and state, e.g. San Francisco, CA"}
      },
      "required" => ["location"]
    }
  end

  @impl true
  def execute(%{"location" => location}) do
    {:ok, "72F and sunny in #{location}"}
  end
end
```

Then drive the full agentic loop with `Anthropic.ToolRunner`:

```elixir
{:ok, message, _history} =
  Anthropic.ToolRunner.run(
    client,
    [model: "claude-opus-4-8", max_tokens: 1024,
     messages: [%{role: "user", content: "What's the weather in Paris?"}]],
    [MyApp.WeatherTool]
  )
```

`ToolRunner` executes every requested tool, feeds results back to the API, and repeats until the assistant stops requesting tools.

### Images

```elixir
{:ok, image} = Anthropic.Messages.Content.Image.process_image("/path/to/image.png", :path)

{:ok, message} =
  Anthropic.Messages.create(client,
    model: "claude-opus-4-8",
    max_tokens: 1024,
    messages: [
      %{role: "user", content: [image, %{type: "text", text: "What's in this image?"}]}
    ]
  )
```

### Models

```elixir
{:ok, %{data: models}} = Anthropic.Models.list(client)
{:ok, model} = Anthropic.Models.retrieve(client, "claude-opus-4-8")

# Or auto-paginate through every page as a lazy Stream:
client |> Anthropic.Models.list_all() |> Enum.each(&IO.puts(&1["id"]))
```

### Batches

```elixir
{:ok, batch} =
  Anthropic.Batches.create(client, [
    %{custom_id: "request-1", params: [model: "claude-opus-4-8", max_tokens: 100, messages: [%{role: "user", content: "Hi"}]]},
    %{custom_id: "request-2", params: [model: "claude-opus-4-8", max_tokens: 100, messages: [%{role: "user", content: "Hello"}]]}
  ])

{:ok, batch} = Anthropic.Batches.retrieve(client, batch.id)

if batch.processing_status == "ended" do
  {:ok, results} = Anthropic.Batches.results(client, batch)
end

# List (a page at a time, or auto-paginated):
{:ok, %{data: batches}} = Anthropic.Batches.list(client)
client |> Anthropic.Batches.list_all() |> Enum.to_list()

{:ok, _deleted} = Anthropic.Batches.delete(client, batch.id)
```

### Counting tokens

```elixir
{:ok, %{input_tokens: n}} =
  Anthropic.Messages.count_tokens(client,
    model: "claude-opus-4-8",
    messages: [%{role: "user", content: "Hello, Claude"}]
  )
```

### Error handling

Every resource function returns `{:ok, result} | {:error, %Anthropic.Error{}}`. `Anthropic.Error` mirrors the API's `error.type` taxonomy (`invalid_request_error`, `rate_limit_error`, `overloaded_error`, `api_error`, etc.) plus client-local types (`:connection_error`, `:timeout`, `:decode_error`, `:validation_error`):

```elixir
case Anthropic.Messages.create(client, model: "claude-opus-4-8", max_tokens: 1024, messages: []) do
  {:ok, message} -> message
  {:error, %Anthropic.Error{type: :validation_error, message: msg}} -> {:error, msg}
  {:error, error} -> raise error
end
```
