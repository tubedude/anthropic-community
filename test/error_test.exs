defmodule Anthropic.ErrorTest do
  use ExUnit.Case, async: true

  alias Anthropic.Error

  describe "from_wire_error/1" do
    test "builds an error from a decoded wire error object" do
      assert %Error{type: :invalid_request_error, message: "bad request"} =
               Error.from_wire_error(%{
                 "type" => "invalid_request_error",
                 "message" => "bad request"
               })
    end

    test "falls back to :api_error for an unrecognized shape" do
      assert %Error{type: :api_error} = Error.from_wire_error(%{"weird" => "shape"})
    end
  end

  describe "from_response/3" do
    test "parses a well-formed API error body" do
      body =
        Jason.encode!(%{
          "type" => "error",
          "error" => %{"type" => "rate_limit_error", "message" => "Too many requests"}
        })

      assert %Error{
               type: :rate_limit_error,
               status: 429,
               message: "Too many requests",
               request_id: "req_123"
             } =
               Error.from_response(429, body, [{"request-id", "req_123"}])
    end

    test "falls back to :api_error for a non-JSON body" do
      assert %Error{type: :api_error, status: 500} = Error.from_response(500, "not json", [])
    end
  end

  describe "retryable?/1" do
    test "rate_limit_error and overloaded_error are retryable" do
      assert Error.retryable?(Error.new(:rate_limit_error, "x"))
      assert Error.retryable?(Error.new(:overloaded_error, "x"))
    end

    test "5xx api_error is retryable, 4xx is not" do
      assert Error.retryable?(Error.new(:api_error, "x", status: 500))
      refute Error.retryable?(Error.new(:api_error, "x", status: 400))
    end

    test "connection_error and timeout are retryable" do
      assert Error.retryable?(Error.new(:connection_error, "x"))
      assert Error.retryable?(Error.timeout())
    end

    test "validation_error is not retryable" do
      refute Error.retryable?(Error.validation("bad params"))
    end
  end

  describe "message/1" do
    test "formats a readable message including status when present" do
      error = Error.new(:api_error, "boom", status: 500)
      assert Exception.message(error) == "[api_error (HTTP 500)] boom"
    end

    test "omits the status segment when absent" do
      error = Error.validation("bad params")
      assert Exception.message(error) == "[validation_error] bad params"
    end
  end
end
