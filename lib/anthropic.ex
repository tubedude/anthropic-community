defmodule Anthropic do
  @moduledoc """
  Provides an unofficial Elixir wrapper for the Anthropic API, facilitating access to the Claude LLM model.
  This module handles configuration, request preparation, and communication with the API, offering an idiomatic Elixir interface to the Anthropic AI capabilities.

  ## Key Features

  - **Configuration Management**: Centralizes settings for the Anthropic API, such as model specifications, API keys, and request parameters, ensuring a consistent request configuration.
  - **Message Handling**: Supports adding various types of messages to the request, including text and image content, enhancing interaction with the Anthropic AI.
  - **Error Handling**: Implements comprehensive error handling for both request generation and response parsing, providing clear feedback on failures.
  - **Telemetry Integration**: Integrates with Elixir's `:telemetry` library to emit events for key operations, enabling monitoring and observability.

  ## Usage

  Start by configuring the API settings, then use the provided functions to add messages or images to your request. Finally, send the request to the Anthropic API and handle the response:

  ```elixir
  config = Anthropic.new(api_key: "your_api_key")
  request = Anthropic.add_user_message(config, "Hello, Anthropic!")
  Anthropic.request_next_message(request)
  ```

  ## Telemetry

  This module emits several `:telemetry` events to help monitor its operations, which can be observed for logging, metrics, or operational insights.

  ### Events

  - `[:anthropic, :request_next_message, :start]` - Emitted at the beginning of a request to the Anthropic API.
  - `[:anthropic, :request_next_message, :stop]` - Emitted after a request to the Anthropic API successfully completes.
  - `[:anthropic, :request_next_message, :exception]` - Emitted if an exception occurs during a request to the Anthropic API.

  ### Metrics

  Each telemetry event includes metadata with the following fields:

  - `:model` - The model specified in the request.
  - `:max_tokens` - The maximum number of tokens allowed in the response.

  In addition, the `:stop` event includes metrics on:

  - `:input_tokens` - The number of tokens in the request.
  - `:output_tokens` - The number of tokens in the API response.

  Errors are captured with their specific types, aiding in debugging and monitoring of the integration's health.
  """

  use Application

  alias Anthropic.Messages.Request
  alias Anthropic.Messages.Content.Image
  alias Anthropic.Config

  @type role :: :user | :assistant
  @type message :: %{role: role, content: any()}

  @doc false
  def start(_type, _args) do
    children = [
      Config,
      {Finch, name: Anthropic.HTTPClient}
    ]

    opts = [strategy: :one_for_one, name: Anthropic.Supervisor]

    Supervisor.start_link(children, opts)
  end

  @spec new(Anthropic.Config.config_options() | nil) :: Anthropic.Messages.Request.t()
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

  @spec add_system_message(Anthropic.Messages.Request.t(), binary()) ::
          Anthropic.Messages.Request.t()
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

  @spec add_message(Anthropic.Messages.Request.t(), role(), any()) :: any()
  @doc """
  Adds a message to the request with a specified role.

  ## Parameters

  - `request`: The `Anthropic.Messages.Request` struct to which the message will be added.
  - `role`: The role of the message (e.g., `:user` or `:assistant`).
  - `message`: The content of the message, can be a binary string, or a list of binary strings that will be treated as different messages.

  ## Returns

  - The updated `Anthropic.Messages.Request` struct with the new message added.
  """
  def add_message(%Request{} = request, role, messages) when is_list(messages) do
    messages
    |> Enum.reduce(request, fn elem, acc -> add_message(acc, role, elem) end)
  end

  def add_message(%Request{messages: messages} = request, role, message) do
    messages =
      messages
      |> Enum.reverse()
      |> then(fn list -> [%{role: role, content: message} | list] end)
      |> Enum.reverse()

    %{request | messages: messages}
  end

  @spec add_user_message(Anthropic.Messages.Request.t(), binary()) ::
          Anthropic.Messages.Request.t()
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

  @spec add_assistant_message(Anthropic.Messages.Request.t(), binary()) ::
          Anthropic.Messages.Request.t()
  @doc """
  Adds a assistant message to the request.

  ## Parameters

  - `request`: The `Anthropic.Messages.Request` struct to which the assistant message will be added.
  - `message`: The content of the assistant message.

  ## Returns

  - The updated `Anthropic.Messages.Request` struct with the assistant message added.
  """
  def add_assistant_message(%Request{} = request, message) do
    add_message(%Request{} = request, :assistant, message)
  end

  @spec add_image(
          Anthropic.Messages.Request.t(),
          {Anthropic.Messages.Content.Image.input_type(), binary()}
        ) :: Anthropic.Messages.Request.t()
  @doc """
  Adds an image message to the request.

  Processes the given image, converts it to a base64 encoded string, and adds it as a message to the request with a role of `:user`.

  ## Parameters

  - `request`: The `Anthropic.Messages.Request` struct to which the image message will be added.
  - `image_data`: A tuple consisting of the input type and the image path or binary data. The input type should be one of `:path`, `:binary`, or `:base64`, indicating how the image is provided.

  ## Returns

  - The updated `Anthropic.Messages.Request` struct with the image message added.

  ## Examples

      Anthropic.add_image(request, {:path, "/path/to/image.png"})
      # Adds an image from a local file path

      Anthropic.add_image(request, {:binary, <<binary data>>})
      # Adds an image from binary data

      Anthropic.add_image(request, {:base64, "base64 encoded image data"})
      # Adds an image from a base64 encoded string

  ## Errors

  - Returns `{:error, reason}` if the image processing fails, where `reason` is a descriptive error message.
  """
  @doc since: "0.2.0"
  def add_image(%Request{} = request, {type, image_path}) do
    {:ok, content} = Image.process_image(image_path, type)
    add_message(request, :user, content)
  end

  @spec request_next_message(Anthropic.Messages.Request.t()) :: any()
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
    :telemetry.span(
      [:anthropic, :request_next_message],
      %{model: request.model, max_tokens: request.max_tokens},
      fn -> request_next_message_core(request, http_client_opts) end
    )
  end

  defp request_next_message_core(%Request{} = request, http_client_opts) do
    Anthropic.Messages.Request.send_request(request, http_client_opts)
    |> prepare_response(request)
    |> wrap_to_telemetry()
  end

  # Prepares the response from the API for successful requests, updating the request with the assistant's message.
  defp prepare_response({:ok, response}, request) do
    updated_request = add_assistant_message(request, response.content)
    {:ok, response, updated_request}
  end

  # Handles error responses from the API, passing through the error and the original request for further handling.
  defp prepare_response({:error, response}, request) do
    {:error, response, request}
  end

  defp wrap_to_telemetry({:ok, response, _updated_request} = result) do
    {result,
     %{
       input_tokens: response.usage["input_tokens"],
       output_tokens: response.usage["output_tokens"]
     }}
  end

  defp wrap_to_telemetry({:error, %{body: body} = _response, _updated_request} = result)
       when is_map(body) do
    {result, %{error: body["error"]["type"]}}
  end

  defp wrap_to_telemetry(
         {:error, %Finch.Error{reason: reason} = _response, _updated_request} = result
       ) do
    {result, %{error: reason}}
  end

  defp wrap_to_telemetry({:error, %Jason.DecodeError{} = _response, _updated_request} = result) do
    {result, %{error: :json_decoding_error}}
  end

  defp wrap_to_telemetry({:error, _response, _updated_request} = result) do
    {result, %{error: :unknown_error}}
  end
end
