## 0.5.0 - 2026-07-10

Complete rewrite into an official-SDK-style client. Breaking change across the entire public API — no compatibility shims.

### Security
- `Anthropic.Client` no longer prints `api_key` via `inspect/1` (`@derive {Inspect, except: [:api_key]}`) — previously any crash report, `Logger` metadata, or `IO.inspect`/`dbg` of a client struct leaked the raw key.
- `Anthropic.Batches.results/2` now refuses to follow a `results_url` whose host doesn't match `Client.base_url`, so a tampered/malicious API response can't redirect the client's `x-api-key` to an attacker-controlled host.
- `Anthropic.HTTPTransport.Retry.delay_ms/2` now caps `retry-after-ms` at 60 seconds (matching the existing cap on the `retry-after` seconds header) — previously an unbounded header value could block a caller indefinitely via `Process.sleep`.
- `Anthropic.HTTPTransport.Multipart` now strips CR/LF from a caller-supplied `:content_type` (as it already did for `name`/`filename`), preventing header injection via `Anthropic.Files.create/3`/`create_from_binary/4`.

### Fixed
- `Anthropic.Messages.Content.Image.process_image/2` now checks a `:path` input's file size against the API's 5MB image limit via `File.stat/1` before reading it into memory, instead of buffering the whole file first.
- `Anthropic.Batches`/`Anthropic.Files` now `URI.encode/1` path segments built from a caller-supplied id (matching `Anthropic.Models.retrieve/2`, which already did).

### Changed
- Collapsed `Anthropic.HTTPTransport`'s duplicated `send_request`/`send_raw` request-attempt-and-retry loops into one (`send_raw`), removing a documented "keep both in sync" maintenance hazard.
- `mix.exs`: added `docs: [main: "readme", extras: [...]]` config so HexDocs gets a proper landing page; `package()` now declares `files:`, `maintainers:`, and a changelog link. Added a top-level `LICENSE` file (Apache-2.0).

### Added
- `:telemetry.span/3` around every `Anthropic.HTTPTransport` request attempt (`[:anthropic, :http, :request, :start/:stop/:exception]`), covering `create/2`, `count_tokens/2`, `Models`, `Batches`, and `Files` uniformly since they all funnel through the shared transport layer. Metadata includes `method`, `url`, `attempt` (retry count), and the resulting `status`.
- `Anthropic.Client` struct (`Client.new/1`), replacing `Anthropic.Config` and the implicit pipeline configuration.
- Typed content blocks: `Anthropic.Messages.Content.{Text, ToolUse, ToolResult, Thinking, RedactedThinking, Image}`.
- Native tool use via the API's real `tools`/`tool_use`/`tool_result` protocol. `Anthropic.Tools` (JSON Schema `input_schema/0`) replaces `Anthropic.Tools.ToolBehaviour`. `Anthropic.ToolRunner.run/4` drives the full agentic loop, replacing the hand-rolled XML-in-system-prompt hack.
- Streaming: `Anthropic.Messages.stream/2` returns a lazy `Stream` of typed `Anthropic.Messages.StreamEvent` structs; `Anthropic.Messages.stream_to_message/1` folds a stream into a final `Message`.
- `Anthropic.Messages.count_tokens/2` (`POST /v1/messages/count_tokens`).
- `Anthropic.Error` — a unified error struct/exception mirroring the API's error taxonomy, with `retryable?/1`.
- Automatic retries with exponential backoff (capped at 8s) and jitter on `408`/`409`/`429`/`5xx`, honoring `retry-after-ms`/`retry-after` and a server-sent `x-should-retry` override, shared by `create/2`, `stream/2`, and `count_tokens/2`.
- `Anthropic.Models` and `Anthropic.Batches` resources, including `Batches.delete/2` and cursor-based auto-pagination (`Models.list_all/2`, `Batches.list_all/2` — lazy `Stream`s that transparently walk pages via `after_id`/`last_id`, backed by the new `Anthropic.Pagination` helper).
- Prompt caching: `Anthropic.CacheControl.ephemeral/1` builds a `cache_control` map; attach it to a `Text`/`Image`/`ToolUse`/`ToolResult` content block's `:cache_control` field.
- Extended thinking request config: `Anthropic.Thinking.enabled/1`, `.adaptive/1`, `.disabled/0` build a `:thinking` param for `Messages.create/2`/`stream/2`.
- Structured outputs: `Anthropic.OutputConfig.json_schema/2` builds an `:output_config` param constraining the response to a given JSON Schema.
- PDF/document content blocks: `Anthropic.Messages.Content.Document` — `process_document/3` (local PDF), `from_url/2`, `from_text/2`, `from_content/2`.
- Citations: typed response-side citation structs (`Anthropic.Messages.Content.Citation.{CharLocation, PageLocation, ContentBlockLocation, SearchResultLocation, WebSearchResultLocation}`), decoded from a `Text` block's `:citations` list instead of raw maps and re-encoded correctly if replayed into a later request. Request-side config is the existing `citations: %{enabled: true}` option on `Document`.
- Server tools (web search, web fetch, code execution, bash, text editor, memory) — executed by Anthropic server-side, no client `execute/1` needed: `Anthropic.Tools.{WebSearch, WebFetch, CodeExecution, Bash, TextEditor, Memory}` build each tool's versioned wire shape (`version:` defaults to latest, overridable). Results decode into `Anthropic.Messages.Content.{ServerToolUse, WebSearchToolResult, WebFetchToolResult, CodeExecutionToolResult, BashCodeExecutionToolResult, TextEditorCodeExecutionToolResult}` — `ServerToolUse` is distinct from `ToolUse` so `Anthropic.ToolRunner` never tries to dispatch a server-tool invocation to a client-side tool. Computer use and the MCP connector are beta-only and not yet supported.
- `Anthropic.Files` resource (beta — automatically sends the required `anthropic-beta: files-api-2025-04-14` header): `create/3` (local path), `create_from_binary/4`, `list/2`, `list_all/2`, `retrieve/2`, `download/2`, `delete/2`. Backed by new `multipart/form-data` support in `Anthropic.HTTPTransport` (`post_multipart/4`, `get_binary/3`, `Anthropic.HTTPTransport.Multipart` encoder) and `get/3`/`delete/3` overloads accepting per-request extra headers.
- Added `nimble_options` and `mime` as dependencies — `nimble_options` validates `CacheControl`/`Thinking`/`OutputConfig`/server-tool option shapes with clear error messages; `mime` guesses a file's content-type from its extension in `Files.create/3`.

### Removed
- `Anthropic` pipeline API (`new/1`, `add_user_message/2`, `request_next_message/1`, `process_invocations/1`, etc).
- `Anthropic.Config`, `Anthropic.Messages.Request`/`Response` (old pipeline versions), `Anthropic.HTTPClient`, `Anthropic.Tools.ToolBehaviour`, `Anthropic.Tools.Utils` (XML tool-calling).

## 0.4.3 - 2024-03-15

### Fixed
- Fixed inconsistency in storing messages in `Anthropic.Request` 

## 0.4.2 - 2024-03-15

### Fixed
- Prevent to add system message when no `Anthropic.Tools.ToolBehaviour` is registered.

## 0.4.1 - 2024-03-15

### Improved
- Removed GenServer from `Anthropic.Config`. It will be created from `Application.get_env` or from the supplied options.
- Added Mox to test environment.
- Increased test coverage.

### Breaking change
- Changed the tool field type to MapSet

### Improved
- Better system function concatenation with tools description
- Moved List.reverse from messages to Jason.Encoder implementation.

## 0.4.0 - 2024-03-13

### Improved
- Added tools handling. Now you can register tools that the AI can call, and these calls are automaticaly captured.

### Fixed
- The way Messages.content was being generated

### Minor
- Moved Response parsing to Request module.

### Breaking change
- Replaced `Anthropic.add_image/2` with `Anthropic.add_user_image/2`

## 0.3.0 - 2024-03-12

### Improved
- Included telemetry
- Added threatment of nil `api_key`

## 0.2.1 - 2024-03-11

### Fixed
- Removed guard that would not allow assistant message to be added to request
- Process response with Jason.decode.

### Improved
- Added type annotations to documentatio

## 0.2.0 - 2024-03-11

### Improved
- Added support for image content
