# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`anthropic_community` — an unofficial Elixir client for the Anthropic Messages API (package name `anthropic`, hex package `anthropic_community`), built in the shape of an official SDK: an explicit `Client` struct, resource modules (`Messages`, `Models`, `Batches`), typed content blocks, native tool use, streaming, and automatic retries. Single-app library, no Phoenix/Ecto.

As of v0.5.0 this is a from-scratch, breaking rewrite of what was previously a builder-pipeline API (`Anthropic.new/1 |> add_user_message/2 |> ...`) with hand-rolled XML-based tool calling. That API no longer exists; there is no compatibility shim.

## Commands

```
mix deps.get                          # install dependencies
mix test                              # run full test suite
mix test test/messages_test.exs       # run one file
mix test test/messages_test.exs:42    # run one test by line
mix format                            # format code
mix format --check-formatted          # verify formatting (not run in CI, but keep code formatted)
mix compile --warnings-as-errors      # compiles clean with zero warnings in the anthropic app
mix docs                              # build ExDoc documentation (ex_doc is a dev-only dep)
```

CI (`.github/workflows/workflows`) runs `mix deps.get && mix test` against a matrix of Elixir/OTP versions. `mix.exs` declares `elixir: "~> 1.15"`.

## Architecture

### The request-sending seam: `Anthropic.HTTPTransport`

Every resource call funnels through `Anthropic.HTTPTransport` (`post/3`, `get/2`, `get_raw/2`, `stream/3`) — this is the **one place** headers, retry/backoff, and error-mapping are defined, so `Messages.create/2`, `Messages.stream/2`, `Models`, and `Batches` never diverge in how they handle a `429` or a dropped connection. Retry policy (`Anthropic.HTTPTransport.Retry`) is exponential backoff with jitter, honoring `retry-after`, capped by `Client.max_retries`.

The actual network layer is a swappable behaviour, `Anthropic.HTTPTransport.Adapter` (`request/3`, `stream/5`), resolved via `Application.get_env(:anthropic, :http_adapter, Finch)`. Tests swap in `Anthropic.MockHTTPAdapter` (a `Mox` mock defined in `test/support/mock_transport.ex`, wired up in `test/test_helper.exs`) — mocking happens at this layer specifically so retry/backoff/SSE-parsing logic in `HTTPTransport` is exercised by real code in tests, not bypassed.

### `Client` is the single config merge point

`Anthropic.Client.new/1` is the only place connection config is merged: explicit opts → `Application.get_env(:anthropic, key)` → `ANTHROPIC_API_KEY`/`ANTHROPIC_BASE_URL` env vars → raise. It's a plain struct passed explicitly as the first argument to every resource function (`Messages.create(client, opts)`, `Models.list(client)`, etc.) rather than held in process/application state — matches how the official SDKs shape their client object, just without the OO dot-chaining.

Per-request params (`model`, `max_tokens`, `messages`, `tools`, ...) are built and validated by `Anthropic.Messages.Request.build/3`, not `Client` — `model`/`max_tokens` are call-site concerns, not connection-level config (`Client.default_model` is an optional convenience only).

### Typed content blocks, not raw maps

`Anthropic.Messages.Content` is the discriminator between the wire JSON shape and typed structs (`Text`, `ToolUse`, `ToolResult`, `Thinking`, `RedactedThinking`, `Image`) via `from_json/1`/`to_json/1`. Response and request content blocks share the same struct types — a block decoded from a response round-trips through `to_json/1` unchanged if replayed into a later request (this is what makes the tool-use loop and multi-turn conversations work without a separate request/response type split). Content-block types the API adds in the future decode as plain maps rather than raising, so this stays forward-compatible.

`Anthropic.Messages.Message` (not `Response`) is the typed result of a non-streaming call; `Message.to_param/1` converts it back into a `messages` request entry.

### Tool use is the API's native protocol, driven by `Anthropic.ToolRunner`

Tools implement `Anthropic.Tools` (`name/0`, `description/0`, `input_schema/0` — a real JSON Schema map, `execute/1`), serialized straight into the wire `tools` field via `Tools.to_param/1`. `Anthropic.ToolRunner.run/4` drives the agentic loop: call `Messages.create/2`, and if `stop_reason == "tool_use"`, execute every `ToolUse` block, then append **all** results for that turn as `tool_result` blocks in a **single** user message (never split across messages — this is a hard requirement of the API's role-alternation contract), and recurse until the assistant stops requesting tools or `max_iterations` is hit. Unregistered tools or execution failures produce `is_error: true` results rather than crashing the loop, so Claude can see the error and adapt.

### Streaming: SSE parser → typed events → accumulator

Three layers, each independently testable:
1. `Anthropic.HTTPTransport.SSE` — a pure line-buffering parser (`feed/2`) that turns raw byte chunks from `Finch.stream/5` into complete `{event_name, data}` frames, buffering partial lines/frames across chunk boundaries. No process/IO concerns.
2. `Anthropic.Messages.StreamEvent.decode/2` — turns one SSE frame's JSON `data` into a typed event struct (`MessageStart`, `ContentBlockStart/Delta/Stop`, `MessageDelta`, `MessageStop`, `Ping`, or a terminal `Error`).
3. `Anthropic.HTTPTransport.stream/3` wires these together via `Stream.resource/3` backed by a `Task.start_link` + message-passing mailbox (Finch's callback runs inside the task; decoded events are `send`'d to the caller's process). `Anthropic.Messages.StreamAccumulator.accumulate/1` folds the resulting event stream into a final `Message` — including reassembling `tool_use` input from split `input_json_delta` string fragments, which only get `Jason.decode`d once the block is complete.

**Retry semantics differ before vs. after the connection opens**: a failure before `Client.max_retries` is exhausted and before a `200` status was observed retries transparently (identical to `post/3`). Once `handle_chunk` has observed `{:status, 200}` (tracked via a `:connected` flag sent to the resource loop), any further failure is always terminal — delivered as a final `%StreamEvent.Error{}` element — because retrying would mean silently replaying or duplicating content already yielded to the caller.

### Images

`Anthropic.Messages.Content.Image.process_image/2` validates MIME type (jpeg/png/gif/webp) and dimensions against the API's supported aspect-ratio/size table before base64-encoding, using `ExImageInfo` to sniff the real format from bytes rather than trusting file extensions. It returns a `%Content.Image{}` struct (a request-side-only content block — the API never returns an `"image"` block in assistant content) that composes with the rest of the typed content system via `Content.to_json/1`.

### Errors are one struct, mirroring the wire taxonomy

`Anthropic.Error` (a `defexception`) carries `:type` (the API's `error.type` values like `:rate_limit_error`, `:overloaded_error`, plus client-local types `:connection_error`, `:timeout`, `:decode_error`, `:validation_error`, `:tool_runner_max_iterations`), `:status`, `:message`, `:request_id`. `Error.retryable?/1` is the single source of truth `HTTPTransport.Retry` consults — every resource function returns `{:ok, result} | {:error, %Error{}}`, with `!` bang variants (`create!/2`) that raise for free since it's an exception struct.
