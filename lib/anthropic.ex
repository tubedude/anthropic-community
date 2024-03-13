defmodule Anthropic do
  @moduledoc """
  Provides an unofficial Elixir wrapper for the Anthropic API, facilitating access to the Claude LLM model.
  This module handles configuration, request preparation, and communication with the API, offering an idiomatic Elixir interface to the Anthropic AI capabilities.

  ## Configuration

  The following configuration options are available:

  - `:api_key` - The API key for authenticating requests to the Anthropic API (required).
  - `:model` - The name of the model to use for generating responses (default: "claude-3-opus-20240229").
  - `:max_tokens` - The maximum number of tokens allowed in the generated response (default: 1000).
  - `:temperature` - The sampling temperature for controlling response randomness (default: 1.0).
  - `:top_p` - The cumulative probability threshold for nucleus sampling (default: 1.0).
  - `:top_k` - The number of top tokens to consider for sampling (default: 1).
  - `:anthropic_version` - The version of the Anthropic API to use (default: "2023-06-01").
  - `:api_url` - The URL of the Anthropic API (default: "https://api.anthropic.com/v1").

  These options can be set in your application's configuration file:

  ```elixir
  config :anthropic,
    api_key: "your_api_key",
    model: "claude-v1",
    max_tokens: 500,
    temperature: 0.7,
    top_p: 0.9,
    top_k: 5
  ```
  Alternatively, you can update the configuration at runtime using Anthropic.Config.reset/1:

  ```elixir
  Anthropic.Config.reset(max_tokens: 750, temperature: 0.5)
  ```
  ## Key Features
  - **Configuration Management**: Centralizes settings for the Anthropic API, such as model specifications, API keys, and request parameters, ensuring a consistent request configuration.
  - **Message Handling**: Supports adding various types of messages to the request, including text and image content, enhancing interaction with the Anthropic AI.
  - **Error Handling**: Implements comprehensive error handling for both request generation and response parsing, providing clear feedback on failures.
  - **Telemetry Integration**: Integrates with Elixir's `:telemetry` library to emit events for key operations, enabling monitoring and observability.
  - **Tool Invocations**: Allows registering and executing custom tool modules that implement the `Anthropic.Tools.ToolBehaviour`, enabling dynamic handling of function invocations from the assistant's responses.

  ## Usage
  Start by configuring the API settings, then use the provided functions to add messages or images to your request. Finally, send the request to the Anthropic API and handle the response:

  ```elixir
  config = Anthropic.new(api_key: "your_api_key")
  request = Anthropic.add_user_message(config, "Hello, Anthropic!")
  {:ok, response, updated_request} = Anthropic.request_next_message(request)
  ```

  ## Configuration
  The following configuration options are available:

  - `:api_key` - The API key for authenticating requests to the Anthropic API.
  - `:model` - The name of the model to use for generating responses (default: "claude-v1").
  - `:max_tokens` - The maximum number of tokens allowed in the generated response (default: 1000).
  - `:temperature` - The sampling temperature for controlling response randomness (default: 1.0).
  - `:top_p` - The cumulative probability threshold for nucleus sampling (default: 1.0).

  ## Error Handling
  The module returns errors in the format `{:error, reason}`, where `reason` can be:

  - A map containing error details from the Anthropic API, with an "error" key indicating the type of error.
  - A `Finch.Error` struct if there was an issue with the HTTP request.
  - A `Jason.DecodeError` struct if there was an issue decoding the JSON response.
  - An `:unknown_error` atom if an unexpected error occurred.

  ## Testing
  When writing tests for code that uses this module, you can mock the API responses using a library like `Mox`. Here's an example of how to mock a successful response:

  ```elixir
  defmodule MyAppTest do
    use ExUnit.Case
    import Mox

    setup :verify_on_exit!

    test "successful request" do
      Mox.expect(AnthropicMock, :post, fn _, _, _ ->
        {:ok, %{body: %{"output" => "Hello, human!"}}}
      end)

      request = Anthropic.new() |> Anthropic.add_user_message("Hello, Anthropic!")
      assert {:ok, response, _} = Anthropic.request_next_message(request)
      assert response.content == "Hello, human!"
    end
  end
  ```

  ## Telemetry

  This module emits several `:telemetry` events to help monitor its operations, which can be observed for logging, metrics, or operational insights.

  ### Events

  - `[:anthropic, :request_next_message, :start]` - Emitted at the beginning of a request to the Anthropic API.
    - Measurements: `%{system_time: integer()}`
    - Metadata: `%{model: String.t(), max_tokens: integer()}`

  - `[:anthropic, :request_next_message, :stop]` - Emitted after a request to the Anthropic API successfully completes.
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{model: String.t(), max_tokens: integer(), input_tokens: integer(), output_tokens: integer()}`

  - `[:anthropic, :request_next_message, :exception]` - Emitted if an exception occurs during a request to the Anthropic API.
    - Measurements: `%{duration: integer()}`
    - Metadata: `%{model: String.t(), max_tokens: integer(), kind: Exception.kind(), reason: term(), stacktrace: Exception.stacktrace()}`

  ### Metrics

  Each telemetry event includes metadata with the following information:

  - `:model` - The name of the model used for the request.
  - `:max_tokens` - The maximum number of tokens allowed in the generated response.
  - `:input_tokens` - The number of tokens in the input message (only available in the `:stop` event).
  - `:output_tokens` - The number of tokens in the generated response (only available in the `:stop` event).
  - `:kind` - The type of exception that occurred (only available in the `:exception` event).
  - `:reason` - The reason for the exception (only available in the `:exception` event).
  - `:stacktrace` - The stacktrace of the exception (only available in the `:exception` event).

  By attaching to these events, you can monitor the performance and health of your Anthropic API integration, track usage metrics, and handle exceptions as needed.
  """

  alias Anthropic.Messages.Response
  alias Anthropic.Messages.Request
  alias Anthropic.Messages.Content.Image
  alias Anthropic.Config

  @type role :: :user | :assistant
  @type message :: %{role: role, content: any()}

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

  @spec register_tool(Anthropic.Messages.Request.t(), atom()) :: Anthropic.Messages.Request.t()
  @doc """
  Registers a tool module with the given request.

  This function allows developers to register tools that implement the `Anthropic.Tools.ToolBehaviour`.
  Registered tools can be utilized to dynamically handle function invocations from the assistant's responses.
  It ensures that each tool module is only registered once per request.

  The `Anthropic.Tools.ToolBehaviour` requires the following callbacks to be implemented:

  - `description/0`: Returns a string describing the purpose and functionality of the tool.
  - `parameters/0`: Returns a list of parameter specifications, each represented as a tuple `{name, type, description}`.
    - `name`: An atom representing the name of the parameter.
    - `type`: The type of the parameter, which can be `:string`, `:float`, or `:integer`.
    - `description`: A string describing the parameter.
  - `invoke/1`: Accepts a list of arguments as strings and returns the result of the tool invocation as a string.

  By implementing these callbacks, developers can create custom tools that can be dynamically invoked by the assistant during the conversation.

  ## Parameters

  - `request`: The `Anthropic.Messages.Request` struct that represents the current state of the conversation.
  - `tool_module`: The module that implements the `Anthropic.Tools.ToolBehaviour`, to be registered with the request.

  ## Returns

  - An updated `Anthropic.Messages.Request` struct with the tool module registered.

  ## Examples

  ```elixir
  defmodule MyCustomTool do
    use Anthropic.Tools.ToolBehaviour

    def description, do: "A custom tool for demonstration purposes"

    def parameters, do: [
      {:name, :string, "The name of the person"},
      {:age, :integer, "The age of the person"}
    ]

    def invoke([name, age]) do
      "Hello, \#{name}! You are \#{age} years old."
    end
  end

  request = Anthropic.register_tool(request, MyCustomTool)
  ```
  """
  def register_tool(%Request{} = request, tool_module) when is_atom(tool_module) do
    case {Code.ensure_loaded?(tool_module), Enum.member?(request.tools, tool_module)} do
      {true, true} ->
        request

      {true, false} ->
        %{request | tools: [tool_module | request.tools]}

      {false, _} ->
        raise ArgumentError,
              "Module #{tool_module} is not loaded. Please use module full name (MyApp.AnthropicTool)"
    end
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
    updated_request =
      request
      |> add_assistant_message(response.content)

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

  @spec process_invocations(
          {:ok, Anthropic.Messages.Response.t(), Anthropic.Messages.Request.t()}
          | {:error, any(), Anthropic.Messages.Request.t()}
        ) ::
          {:ok, Anthropic.Messages.Response.t(), Anthropic.Messages.Request.t()}
          | {:error, any(), Anthropic.Messages.Request.t()}
  @doc """
  Processes the tool invocations present in the assistant's response.

  This function takes the result of `request_next_message/1` and checks if there are any tool invocations in the response. If invocations are found, it executes each one using the registered tools and appends the results to the conversation. It then sends the updated conversation back to the API for further processing.

  ## Parameters
  - `result`: The result of `request_next_message/1`, which can be either `{:ok, response, request}` or `{:error, response, request}`.

  ## Returns
  - `{:ok, response, updated_request}`: If the invocations are processed successfully, where `response` is the original response from the API, and `updated_request` is the request struct updated with the invocation results.
  - `{:error, response, request}`: If an error occurs during the processing of invocations, where `response` contains the error details, and `request` is the original request struct.

  ## Raises
  - `ArgumentError`: If a tool invocation fails due to the specified tool not being registered or if there's an error during the execution of the tool.

  This function is responsible for handling the dynamic execution of tools based on the assistant's responses. It allows for a more interactive and extensible conversation flow by processing tool invocations and incorporating their results into the ongoing conversation.
  """
  def process_invocations({:ok, %Response{} = response, %Request{} = request}) do
    case cycle_invocations(response, request) do
      {:ok, [], updated_request} ->
        {:ok, response, updated_request}

      {:ok, invocation_responses, updated_request} ->
        invocation_responses
        |> Enum.join("\n")
        |> then(&add_user_message(updated_request, &1))
        |> request_next_message()
    end
  end

  def process_invocations({:error, _, _} = resp), do: resp

  defp cycle_invocations(%Response{invocations: []}, %Request{} = request) do
    {:ok, [], request}
  end

  defp cycle_invocations(%Response{invocations: invocations}, %Request{} = request) do
    {responses, updated_request} =
      Enum.map_reduce(invocations, request, fn {tool_name, args}, req ->
        case process_invocation(tool_name, args, req) do
          {:ok, result, updated_req} -> {result, updated_req}
          {:error, reason} -> raise ArgumentError, "Invocation error: #{reason}"
        end
      end)

    {:ok, responses, updated_request}
  end

  defp process_invocation(tool_name, args, %Request{} = request) do
    case Enum.find(request.tools, &(&1 == tool_name)) do
      nil ->
        {:error, "Tool #{tool_name} not found"}

      tool_module ->
        task = Anthropic.Tools.Utils.execute_async(tool_module, args)
        result = Anthropic.Tools.Utils.format_response(task, tool_name)
        {:ok, result, request}
    end
  end
end
