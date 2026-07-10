defmodule Anthropic.HTTPTransport.Multipart do
  @moduledoc """
  Minimal `multipart/form-data` body encoder (RFC 7578) — just enough for file uploads
  (`Anthropic.Files.create/2`), not a general-purpose multipart library.
  """

  @type field ::
          {name :: String.t(), value :: String.t()}
          | {name :: String.t(), data :: binary(), keyword()}

  @doc """
  Encodes `fields` into a multipart body. A plain `{name, value}` tuple becomes a simple
  form field; `{name, data, filename: ..., content_type: ...}` becomes a file field.

  Returns `{boundary, iodata}` — the caller is responsible for setting the
  `content-type: multipart/form-data; boundary=<boundary>` request header.
  """
  @spec encode(list(field())) :: {boundary :: String.t(), iodata()}
  def encode(fields) do
    boundary = generate_boundary()
    body = Enum.map(fields, &encode_field(&1, boundary)) ++ ["--", boundary, "--\r\n"]
    {boundary, body}
  end

  defp generate_boundary do
    "ex-multipart-" <> (16 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower))
  end

  defp encode_field({name, value}, boundary) when is_binary(value) do
    [
      "--",
      boundary,
      "\r\n",
      "Content-Disposition: form-data; name=\"",
      name,
      "\"\r\n\r\n",
      value,
      "\r\n"
    ]
  end

  defp encode_field({name, data, opts}, boundary) when is_binary(data) do
    filename = Keyword.fetch!(opts, :filename)
    content_type = Keyword.get(opts, :content_type, "application/octet-stream")

    [
      "--",
      boundary,
      "\r\n",
      "Content-Disposition: form-data; name=\"",
      name,
      "\"; filename=\"",
      filename,
      "\"\r\n",
      "Content-Type: ",
      content_type,
      "\r\n\r\n",
      data,
      "\r\n"
    ]
  end
end
