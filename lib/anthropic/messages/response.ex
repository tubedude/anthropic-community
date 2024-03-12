defmodule Anthropic.Messages.Response do
  @moduledoc """
  Handles parsing and encapsulation of responses from the Anthropic API.

  This module defines the structure of a response from the Anthropic API and provides functionality to parse the raw response into a structured format. It deals with successful responses as well as various error conditions, translating HTTP responses into a consistent format for the caller to handle.
  """

  @fields [:id, :type, :role, :content, :model, :stop_reason, :stop_sequence, :usage]

  defstruct @fields

  @doc """
  Parses an HTTP response from the Anthropic API.

  This function handles different types of HTTP responses based on their status code. It extracts relevant fields from successful responses (status 200) and constructs a struct representing the parsed response. For error responses (status codes 400-499 for client errors and 500-599 for server errors), it returns an error tuple. Errors encountered during the HTTP request process are also passed through.

  ## Parameters

  - `response`: A tuple containing the raw HTTP response. This can be either `{:ok, %Finch.Response{}}` indicating a potentially successful or error response, or `{:error, response}` indicating an error during the request process.

  ## Returns

  - For successful responses (status 200), returns `{:ok, response_struct}` where `response_struct` is the struct representation of the parsed response.
  - For client errors (status codes 400-499) and server errors (status codes 500-599), returns `{:error, response}` where `response` is the original response indicating an error.
  - For errors during the request process, returns `{:error, response}` where `response` is the original error response.
  """
  def parse({:ok, %Finch.Response{status: 200} = response}) do
    case Jason.decode(response.body) do
      {:error, _} = error -> error
      {:ok, body} ->
        @fields
        |> Enum.map(fn field -> {field, body[Atom.to_string(field)]} end)
        |> then(fn list -> {:ok, struct(%__MODULE__{}, list)} end)
    end
  end

  def parse({:ok, %Finch.Response{status: status} = response}) when status in 500..599,
    do: {:error, response}

  def parse({:ok, %Finch.Response{status: status} = response}) when status in 400..499,
    do: {:error, response}

  def parse({:error, response}),
    do: {:error, response}
end
