defmodule Anthropic do
  @moduledoc """
  Provides an unofficial Elixir wrapper for the Anthropic API, facilitating access to the Claude LLM model.
  This module handles configuration, request preparation, and communication with the API.
  """

  use Application

  alias Anthropic.Messages.Request
  alias Anthropic.Config

  @doc false
  def start(_type, _args) do
    children = [
      Config,
      {Finch, name: Anthropic.HTTPClient}
    ]

    opts = [strategy: :one_for_one, name: Anthropic.Supervisor]

    Supervisor.start_link(children, opts)
  end

  @doc """
  Initializes a new `Anthropic.Config` struct with the given options, merging them with the default configuration.

  ## Parameters

  - `opts`: (Optional) A keyword list of options to override the default configuration settings.

  ## Returns

  - A new `Anthropic.Messages.Request` struct populated with the merged configuration options.
  """
  def new(opts \\ []) do
    Config.opts()
    |> Map.merge(Enum.into(opts, %{}))
    |> then(fn map -> struct(Anthropic.Config, map) end)
    |> Request.create()
  end

  @doc """
  Adds a system message to the request.

  ## Parameters

  - `request`: The current `Anthropic.Messages.Request` struct to which the system message will be added.
  - `message`: The system message to add, must be a binary string.

  ## Returns

  - The updated `Anthropic.Messages.Request` struct with the system message added.

  ## Errors

  - Raises `ArgumentError` if the message is not a binary string.
  """
  def add_system_message(%Request{} = request, message) when is_binary(message) do
    %{request | system: message}
  end

  def add_system_message(_, message),
    do:
      raise(
        ArgumentError,
        "System message must be type String, got #{inspect(message, limit: 50, structs: false, width: 80)}"
      )

  @doc """
  Adds a message to the request with a specified role.

  ## Parameters

  - `request`: The `Anthropic.Messages.Request` struct to which the message will be added.
  - `role`: The role of the message (e.g., `:user` or `:assistant`).
  - `message`: The content of the message, can be a binary string, or a list of binary strings that will be treated as different messages.

  ## Returns

  - The updated `Anthropic.Messages.Request` struct with the new message added.
  """
  def add_message(%Request{messages: messages} = request, role, message)
      when is_binary(message) do
    messages =
      messages
      |> Enum.reverse()
      |> then(fn list -> [%{role: role, content: message} | list] end)
      |> Enum.reverse()

    %{request | messages: messages}
  end

  def add_message(%Request{} = request, role, messages) when is_list(messages) do
    messages
    |> Enum.reduce(request, fn elem, acc -> add_message(acc, role, elem) end)
  end

  @doc """
  Adds a user message to the request.

  ## Parameters

  - `request`: The `Anthropic.Messages.Request` struct to which the user message will be added.
  - `message`: The content of the user message, must be a binary string.

  ## Returns

  - The updated `Anthropic.Messages.Request` struct with the user message added.
  """
  def add_user_message(%Request{} = request, message) when is_binary(message) do
    add_message(%Request{} = request, :user, message)
  end

  @doc """
  Adds a assistant message to the request.

  ## Parameters

  - `request`: The `Anthropic.Messages.Request` struct to which the assistant message will be added.
  - `message`: The content of the assistant message, must be a binary string.

  ## Returns

  - The updated `Anthropic.Messages.Request` struct with the assistant message added.
  """
  def add_assistant_message(%Request{} = request, message) when is_binary(message) do
    add_message(%Request{} = request, :assistant, message)
  end

  @doc """
  Sends the current request to the Anthropic API and awaits the next message in the conversation.

  This function encapsulates the process of sending the prepared request to the Anthropic API, parsing the response, and preparing the next step of the conversation based on the API's response.

  ## Parameters

  - `request`: The `Anthropic.Messages.Request` struct that contains the current state of the conversation.
  - `http_client_opts`: (Optional) A list of options for the HTTP client used to make the request. These options are passed directly to the HTTP client.

  ## Returns

  - On success, returns a tuple `{:ok, response_content, updated_request}` where `response_content` is the content of the response from the API, and `updated_request` is the updated request struct including the response message.
  - On failure, returns a tuple `{:error, response, request}` where `response` contains error information provided by the API or HTTP client.

  This function is the main mechanism through which conversations are advanced, by sending user or assistant messages to the API and incorporating the API's responses into the ongoing conversation.
  """
  def request_next_message(%Request{} = request, http_client_opts \\ []) do
    Anthropic.Messages.Request.send_request(request, http_client_opts)
    |> Anthropic.Messages.Response.parse()
    |> prepare_response(request)
  end

  # Prepares the response from the API for successful requests, updating the request with the assistant's message.
  defp prepare_response({:ok, response}, request) do
    updated_request = add_assistant_message(request, response.content)

    {:ok, response.content, updated_request}
  end

  # Handles error responses from the API, passing through the error and the original request for further handling.
  defp prepare_response({:error, response}, request) do
    {:error, response, request}
  end
end
