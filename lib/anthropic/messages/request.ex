defmodule Anthropic.Messages.Request do
  @moduledoc """
  Defines the structure and functionality for creating and sending requests to the Anthropic API.

  This module is responsible for encapsulating the data needed for a request, including model specifications, messages, and various control parameters. It also implements the `Jason.Encoder` protocol to ensure that instances of this struct can be serialized to JSON format, which is required for API requests.

  The following configuration options are available:

  - `:model` - The name of the model to use for generating responses (default: "claude-3-opus-20240229").
  - `:max_tokens` - The maximum number of tokens allowed in the generated response (default: 1000).
  - `:temperature` - The sampling temperature for controlling response randomness (default: 1.0).
  - `:top_p` - The cumulative probability threshold for nucleus sampling (default: 1.0).
  - `:top_k` - The number of most probable next words considered at each step in sampling for text generation. (default: nil).

  """

  @endpoint "/messages"

  require Logger

  alias Anthropic.{Config, HTTPClient}
  alias Anthropic.HttpClient.Utils

  @doc """
  The structure of a request to the Anthropic API.

  Includes all necessary fields for making a request, such as model information, messages to process, and parameters to control the behavior of the API response.
  """
  defstruct model: nil,
            messages: [],
            system: nil,
            max_tokens: nil,
            metadata: nil,
            stop_sequences: nil,
            stream: false,
            temperature: nil,
            top_p: nil,
            top_k: nil,
            tools: MapSet.new()

  @type t :: %__MODULE__{
          model: String.t() | nil,
          messages: list(message()),
          system: String.t() | nil,
          max_tokens: integer() | nil,
          metadata: map() | nil,
          stop_sequences: list(String.t()) | nil,
          stream: boolean(),
          temperature: float() | nil,
          top_p: float() | nil,
          top_k: integer() | nil,
          tools: MapSet.t(atom())
        }

  @type message() :: %{
          content: content_object(),
          role: String.t()
        }

  @type content_object ::
          %{type: String.t(), text: String.t()}
          | %{
              type: String.t(),
              source: %{data: String.t(), type: String.t(), media_type: String.t()}
            }

  defimpl Jason.Encoder, for: Anthropic.Messages.Request do
    def encode(req, opts) do
      %{
        messages: Enum.reverse(req.messages),
        model: req.model,
        system: Anthropic.Tools.Utils.decorate_tools_description(req.system, req.tools),
        max_tokens: req.max_tokens,
        metadata: req.metadata,
        stop_sequences: req.stop_sequences,
        stream: req.stream,
        temperature: req.temperature,
        top_p: req.top_p,
        top_k: req.top_k
      }
      |> Map.reject(fn {_key, value} -> is_nil(value) end)
      |> Jason.Encode.map(opts)
    end
  end

  @spec create(Anthropic.Config.t()) :: Anthropic.Messages.Request.t()
  @doc """
  Creates a new request struct based on the provided configuration.

  Initializes a request with the parameters specified in the configuration, setting up default values for the request structure.

  ## Parameters

  - `opts`: The Anthropic.Config struct containing configuration options for the request.

  ## Returns

  - A new Anthropic.Messages.Request struct initialized with the provided configuration options.
  """
  def create(%Anthropic.Config{} = opts) do
    %__MODULE__{
      model: opts.model,
      max_tokens: opts.max_tokens,
      temperature: opts.temperature,
      top_p: opts.top_p,
      top_k: opts.top_k
    }
  end

  @spec send_request(Anthropic.Messages.Request.t(), Keyword.t() | nil) ::
          {:error, any()} | {:ok, Anthropic.Messages.Response.t()}
  @doc """
  Encodes the request to JSON and sends it to the Anthropic API via the Finch HTTP client.

  This function serializes the request struct into JSON, builds the request with the correct headers and path, and sends it using Finch.

  ## Parameters

  - `request`: The Anthropic.Messages.Request struct to send.
  - `opts`: Additional options for the Finch request.

  ## Returns

  - `{:ok, response}` on successful request and response parsing.
  - `{:error, reason}` if the request fails due to encoding issues or HTTP errors.
  """
  def send_request(%__MODULE__{} = request, opts) do
    with {:ok, body} <- Jason.encode(request),
         {:ok, response} <- build_finch_request(body, opts) do
      {:ok, response}
    else
      {:error, %Jason.EncodeError{}} -> {:error, :invalid_body_format}
      {:error, %{reason: reason}} -> {:error, reason}
      {:error, _} = error -> error
    end
    |> Anthropic.Messages.Response.parse(request)
  end

  defp build_finch_request(body, opts) do
    sys_opts = Config.opts()

    req =
      Finch.build(
        :post,
        Utils.build_path(@endpoint, sys_opts.api_url),
        Utils.build_header(sys_opts),
        body
      )

    Logger.debug(inspect(req))
    Finch.request(req, HTTPClient, opts)
  end
end
