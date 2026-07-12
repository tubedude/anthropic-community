defmodule Anthropic.HTTPTransport.MultipartTest do
  use ExUnit.Case, async: true

  alias Anthropic.HTTPTransport.Multipart

  describe "encode/1" do
    test "encodes a plain form field" do
      {boundary, body} = Multipart.encode([{"purpose", "vision"}])
      encoded = IO.iodata_to_binary(body)

      assert encoded == """
             --#{boundary}\r
             Content-Disposition: form-data; name="purpose"\r
             \r
             vision\r
             --#{boundary}--\r
             """
    end

    test "encodes a file field with filename and content_type" do
      {boundary, body} =
        Multipart.encode([
          {"file", "binarydata", filename: "photo.png", content_type: "image/png"}
        ])

      encoded = IO.iodata_to_binary(body)

      assert encoded == """
             --#{boundary}\r
             Content-Disposition: form-data; name="file"; filename="photo.png"\r
             Content-Type: image/png\r
             \r
             binarydata\r
             --#{boundary}--\r
             """
    end

    test "defaults content_type to application/octet-stream when omitted" do
      {boundary, body} = Multipart.encode([{"file", "data", filename: "f.bin"}])
      encoded = IO.iodata_to_binary(body)

      assert encoded =~ "Content-Type: application/octet-stream\r\n"
      assert encoded =~ "--#{boundary}"
    end

    test "encodes multiple fields with a single boundary" do
      {boundary, body} =
        Multipart.encode([
          {"purpose", "vision"},
          {"file", "data", filename: "f.png", content_type: "image/png"}
        ])

      encoded = IO.iodata_to_binary(body)

      # boundary appears: field1 start, field2 start, final closing boundary — 3 times
      assert encoded |> String.split("--#{boundary}") |> length() == 4
      assert encoded =~ "name=\"purpose\""
      assert encoded =~ "name=\"file\"; filename=\"f.png\""
      assert String.ends_with?(encoded, "--#{boundary}--\r\n")
    end

    test "generates a fresh boundary on every call" do
      {boundary1, _} = Multipart.encode([{"a", "b"}])
      {boundary2, _} = Multipart.encode([{"a", "b"}])
      assert boundary1 != boundary2
    end

    test "escapes a double quote in a filename so it can't break out of the quoted header param" do
      {_boundary, body} = Multipart.encode([{"file", "data", filename: ~s(my"file.pdf)}])
      encoded = IO.iodata_to_binary(body)

      assert encoded =~ ~s(filename="my%22file.pdf")
      refute encoded =~ ~s(filename="my"file.pdf")
    end

    test "strips CR/LF from a filename so it can't inject extra header lines" do
      {_boundary, body} =
        Multipart.encode([{"file", "data", filename: "evil\r\nContent-Type: text/html"}])

      encoded = IO.iodata_to_binary(body)

      assert encoded =~ ~s(filename="evilContent-Type: text/html")
      refute encoded =~ "evil\r\nContent-Type"
    end

    test "escapes a double quote in a plain field name" do
      {_boundary, body} = Multipart.encode([{~s(weird"name), "value"}])
      encoded = IO.iodata_to_binary(body)

      assert encoded =~ ~s(name="weird%22name")
    end
  end
end
