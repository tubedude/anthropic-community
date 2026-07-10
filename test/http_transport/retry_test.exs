defmodule Anthropic.HTTPTransport.RetryTest do
  use ExUnit.Case, async: true

  alias Anthropic.{Error, HTTPTransport.Retry}

  describe "should_retry?/4" do
    test "true for a retryable error within budget" do
      assert Retry.should_retry?(Error.new(:api_error, "x", status: 500), 0, 2)
    end

    test "false once attempt reaches max_retries, even for a retryable error" do
      refute Retry.should_retry?(Error.new(:api_error, "x", status: 500), 2, 2)
    end

    test "false for a non-retryable error" do
      refute Retry.should_retry?(Error.validation("bad params"), 0, 2)
    end

    test "408 and 409 are retryable regardless of error type" do
      assert Retry.should_retry?(Error.new(:invalid_request_error, "x", status: 408), 0, 2)
      assert Retry.should_retry?(Error.new(:invalid_request_error, "x", status: 409), 0, 2)
    end

    test "x-should-retry: true overrides an otherwise non-retryable error" do
      error = Error.validation("bad params")
      assert Retry.should_retry?(error, 0, 2, [{"x-should-retry", "true"}])
    end

    test "x-should-retry: false overrides an otherwise retryable error" do
      error = Error.new(:api_error, "x", status: 500)
      refute Retry.should_retry?(error, 0, 2, [{"x-should-retry", "false"}])
    end

    test "x-should-retry: true still respects the max_retries budget" do
      error = Error.validation("bad params")
      refute Retry.should_retry?(error, 2, 2, [{"x-should-retry", "true"}])
    end

    test "header lookup is case-insensitive" do
      error = Error.validation("bad params")
      assert Retry.should_retry?(error, 0, 2, [{"X-Should-Retry", "true"}])
    end
  end

  describe "delay_ms/2" do
    test "honors retry-after-ms when present" do
      assert Retry.delay_ms(0, [{"retry-after-ms", "1500"}]) == 1500
    end

    test "prefers retry-after-ms over retry-after" do
      assert Retry.delay_ms(0, [{"retry-after-ms", "250"}, {"retry-after", "10"}]) == 250
    end

    test "honors retry-after in seconds, converted to ms" do
      assert Retry.delay_ms(0, [{"retry-after", "2"}]) == 2000
    end

    test "ignores an out-of-sanity-range retry-after (> 60s)" do
      ms = Retry.delay_ms(0, [{"retry-after", "3600"}])
      assert ms < 60_000
    end

    test "ignores a non-positive retry-after and falls through to exponential backoff" do
      assert Retry.delay_ms(0, [{"retry-after", "0"}]) in 375..500
    end

    test "exponential backoff grows with attempt and is capped at 8000ms" do
      ms0 = Retry.delay_ms(0, [])
      ms1 = Retry.delay_ms(1, [])
      ms_high = Retry.delay_ms(10, [])

      assert ms0 in 375..500
      assert ms1 in 750..1000
      assert ms_high <= 8_000
    end

    test "no headers defaults to exponential backoff" do
      assert Retry.delay_ms(0) in 375..500
    end
  end
end
