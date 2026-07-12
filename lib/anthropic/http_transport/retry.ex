defmodule Anthropic.HTTPTransport.Retry do
  @moduledoc """
  Exponential backoff + jitter, shared by both plain requests (`HTTPTransport.post/3`) and
  the initial connection attempt of `HTTPTransport.stream/3`, so retry behavior never
  diverges between the two.
  """

  @initial_delay_ms 500
  @max_delay_ms 8_000
  @max_retry_after_ms 60_000

  @doc """
  Whether attempt number `attempt` (0-indexed) should be retried. A response-level
  `x-should-retry: true`/`false` header always wins (matching the API's own override
  signal); otherwise falls back to `Anthropic.Error.retryable?/1`. Always bounded by
  `max_retries`, even when the header says to retry.
  """
  @spec should_retry?(
          Anthropic.Error.t(),
          attempt :: non_neg_integer(),
          max_retries :: non_neg_integer(),
          headers :: list({String.t(), String.t()})
        ) :: boolean()
  def should_retry?(error, attempt, max_retries, headers \\ []) do
    attempt < max_retries and eligible?(error, headers)
  end

  defp eligible?(error, headers) do
    case should_retry_header(headers) do
      true -> true
      false -> false
      nil -> Anthropic.Error.retryable?(error)
    end
  end

  defp should_retry_header(headers) do
    case find_header(headers, "x-should-retry") do
      "true" -> true
      "false" -> false
      _other -> nil
    end
  end

  @doc """
  Computes the delay in milliseconds before the next attempt. Honors a `retry-after-ms`
  header (preferred, more precise, sanity-bounded to `0 < ms <= 60_000`) or `retry-after`
  header (seconds, sanity-bounded to `0 < seconds <= 60`) when present; otherwise uses
  exponential backoff — `500ms, 1s, 2s, 4s, ...` capped at 8s — with up to 25% negative jitter.
  """
  @spec delay_ms(attempt :: non_neg_integer(), headers :: list({String.t(), String.t()})) ::
          non_neg_integer()
  def delay_ms(attempt, headers \\ []) do
    case retry_after_ms(headers) do
      ms when is_integer(ms) -> ms
      nil -> exponential_backoff_ms(attempt)
    end
  end

  defp retry_after_ms(headers) do
    parse_retry_after_ms(find_header(headers, "retry-after-ms")) ||
      parse_retry_after_seconds(find_header(headers, "retry-after"))
  end

  defp parse_retry_after_ms(nil), do: nil

  defp parse_retry_after_ms(value) do
    case Float.parse(value) do
      {ms, _rest} when ms > 0 and ms <= @max_retry_after_ms -> round(ms)
      _ -> nil
    end
  end

  defp parse_retry_after_seconds(nil), do: nil

  defp parse_retry_after_seconds(value) do
    case Float.parse(value) do
      {seconds, _rest} when seconds > 0 and seconds <= 60 -> round(seconds * 1000)
      _ -> nil
    end
  end

  defp exponential_backoff_ms(attempt) do
    base = min(@initial_delay_ms * :math.pow(2, attempt), @max_delay_ms)
    jitter = 1 - 0.25 * :rand.uniform()
    max(round(base * jitter), 0)
  end

  defp find_header(headers, name) do
    Enum.find_value(headers, fn {k, v} -> if String.downcase(k) == name, do: v end)
  end
end
