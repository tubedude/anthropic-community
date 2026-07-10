## 0.5.0 - 2026-07-10

Complete rewrite into an official-SDK-style client. Breaking change across the entire public API — no compatibility shims.

### Added
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
- Added `nimble_options` as a dependency, used to validate `CacheControl`/`Thinking`/`OutputConfig` option shapes with clear error messages.

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
