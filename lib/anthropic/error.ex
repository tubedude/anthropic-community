defmodule Anthropic.Error do
  @moduledoc """
  Unified error type returned as `{:error, %Anthropic.Error{}}` from every resource
  function, and raised by the `!` bang variants (this struct is a `defexception`).

  `:type` mirrors the Anthropic API's `error.type` taxonomy (`invalid_request_error`,
  `authentication_error`, `permission_error`, `not_found_error`, `request_too_large`,
  `rate_limit_error`, `api_error`, `overloaded_error`) for errors that came back from the
  API, plus client-local types for failures that never reach the wire: `:connection_error`,
  `:timeout`, `:decode_error`, `:validation_error`, `:tool_runner_max_iterations`.
  """

  defexception [:type, :status, :message, :request_id]

  @type t :: %__MODULE__{
          type: atom(),
          status: pos_integer() | nil,
          message: String.t(),
          request_id: String.t() | nil
        }

  @impl true
  def message(%__MODULE__{type: type, status: status, message: msg}) do
    "[#{type}#{if status, do: " (HTTP #{status})", else: ""}] #{msg}"
  end

  @spec new(atom(), String.t(), keyword()) :: t()
  def new(type, message, opts \\ []) do
    %__MODULE__{
      type: type,
      message: message,
      status: Keyword.get(opts, :status),
      request_id: Keyword.get(opts, :request_id)
    }
  end

  @spec validation(String.t()) :: t()
  def validation(message), do: new(:validation_error, message)

  @spec timeout() :: t()
  def timeout, do: new(:timeout, "request timed out")

  @doc """
  Builds an Error from a decoded wire error object: `%{"type" => ..., "message" => ...}`
  (the value of the top-level `"error"` key in an API error response body).
  """
  @spec from_wire_error(map()) :: t()
  def from_wire_error(%{"type" => type, "message" => message}) when is_binary(type) do
    new(String.to_atom(type), message)
  end

  def from_wire_error(other), do: new(:api_error, inspect(other))

  @doc """
  Builds an Error from a raw HTTP error response: status code, raw body, and headers
  (used to extract a `request-id` for support/debugging).
  """
  @spec from_response(pos_integer(), String.t(), list({String.t(), String.t()})) :: t()
  def from_response(status, body, headers) do
    request_id = find_header(headers, "request-id")

    case Jason.decode(body) do
      {:ok, %{"error" => wire_error}} ->
        %{from_wire_error(wire_error) | status: status, request_id: request_id}

      _ ->
        new(:api_error, "HTTP #{status}: #{body}", status: status, request_id: request_id)
    end
  end

  @doc """
  Whether this error is safe to retry (used by the retry/backoff layer). Status-driven
  first — retries on `408` (request timeout), `409` (lock timeout), and any `5xx`,
  regardless of the wire `error.type` — then falls back to semantic error types for
  failures with no HTTP status at all (`:rate_limit_error`, `:overloaded_error`,
  `:connection_error`, `:timeout`).
  """
  @spec retryable?(t()) :: boolean()
  def retryable?(%__MODULE__{status: status}) when status in [408, 409], do: true
  def retryable?(%__MODULE__{status: status}) when is_integer(status) and status >= 500, do: true
  def retryable?(%__MODULE__{type: :rate_limit_error}), do: true
  def retryable?(%__MODULE__{type: :overloaded_error}), do: true
  def retryable?(%__MODULE__{type: :connection_error}), do: true
  def retryable?(%__MODULE__{type: :timeout}), do: true
  def retryable?(%__MODULE__{}), do: false

  defp find_header(headers, name) do
    Enum.find_value(headers, fn {k, v} -> if String.downcase(k) == name, do: v end)
  end
end
