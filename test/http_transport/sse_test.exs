defmodule Anthropic.HTTPTransport.SSETest do
  use ExUnit.Case, async: true

  alias Anthropic.HTTPTransport.SSE

  describe "feed/2" do
    test "parses a single complete frame in one chunk" do
      chunk = "event: ping\ndata: {}\n\n"

      assert {[{"ping", "{}"}], %SSE{buffer: ""}} = SSE.feed(SSE.new(), chunk)
    end

    test "parses multiple frames in one chunk" do
      chunk = "event: a\ndata: 1\n\nevent: b\ndata: 2\n\n"

      assert {[{"a", "1"}, {"b", "2"}], _} = SSE.feed(SSE.new(), chunk)
    end

    test "buffers a partial line across chunk boundaries" do
      {frames1, parser} = SSE.feed(SSE.new(), "event: ping\ndata: {\"a\":")
      assert frames1 == []

      {frames2, _parser} = SSE.feed(parser, "1}\n\n")
      assert frames2 == [{"ping", "{\"a\":1}"}]
    end

    test "buffers a split mid-data-line across chunk boundaries" do
      {frames1, parser} = SSE.feed(SSE.new(), "event: content_block_delta\ndata: {\"partial")
      assert frames1 == []

      {frames2, parser} = SSE.feed(parser, "_json\":\"x\"}")
      assert frames2 == []

      {frames3, _parser} = SSE.feed(parser, "\n\n")
      assert frames3 == [{"content_block_delta", "{\"partial_json\":\"x\"}"}]
    end

    test "buffers a frame split exactly on the blank-line boundary" do
      {frames1, parser} = SSE.feed(SSE.new(), "event: ping\ndata: {}\n")
      assert frames1 == []

      {frames2, _parser} = SSE.feed(parser, "\n")
      assert frames2 == [{"ping", "{}"}]
    end

    test "joins multi-line data fields with newlines" do
      chunk = "event: x\ndata: line1\ndata: line2\n\n"

      assert {[{"x", "line1\nline2"}], _} = SSE.feed(SSE.new(), chunk)
    end

    test "ignores SSE comment lines" do
      chunk = ": heartbeat\nevent: ping\ndata: {}\n\n"

      assert {[{"ping", "{}"}], _} = SSE.feed(SSE.new(), chunk)
    end

    test "ignores blank lines with no pending data (keep-alive newlines)" do
      chunk = "\n\n\nevent: ping\ndata: {}\n\n"

      assert {[{"ping", "{}"}], _} = SSE.feed(SSE.new(), chunk)
    end

    test "handles a frame with no event name (data-only)" do
      chunk = "data: {\"type\":\"message_stop\"}\n\n"

      assert {[{nil, "{\"type\":\"message_stop\"}"}], _} = SSE.feed(SSE.new(), chunk)
    end

    test "handles CRLF line endings, per the SSE spec" do
      chunk = "event: ping\r\ndata: {}\r\n\r\n"

      assert {[{"ping", "{}"}], _} = SSE.feed(SSE.new(), chunk)
    end

    test "handles a CRLF frame split across chunk boundaries" do
      {frames1, parser} = SSE.feed(SSE.new(), "event: ping\r\ndata: {\"a\":1}\r")
      assert frames1 == []

      {frames2, _parser} = SSE.feed(parser, "\n\r\n")
      assert frames2 == [{"ping", "{\"a\":1}"}]
    end
  end
end
