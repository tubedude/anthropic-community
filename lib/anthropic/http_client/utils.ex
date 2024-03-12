defmodule Anthropic.HttpClient.Utils do
  @moduledoc """
  Provides utility functions for constructing HTTP requests for use with the Finch HTTP client.
  This module facilitates the assembly of request paths and headers based on configuration options,
  specifically tailored for interacting with the Anthropic API.
  """

  alias Anthropic.Config

  @doc """
  Builds the complete request URL from a base API URL and a specific path.

  This function constructs the full URL by appending the given path to the base API URL. It is designed to ensure that the URL structure is correctly formed for API requests.

  ## Parameters

  - `path`: The specific API endpoint path to be appended to the base URL.
  - `api_url`: The base URL of the API.

  ## Returns

  - A string representing the complete URL for the API request.

  ## Examples

      iex> Anthropic.HTTPClient.Utils.build_path("/v1/models", "https://api.anthropic.com")
      "https://api.anthropic.com/v1/models"
  """
  def build_path(path, api_url) do
    api_url
    |> URI.parse()
    |> URI.append_path(path)
    |> URI.to_string()
  end

  @doc """
  Constructs the headers for an HTTP request based on the provided `Anthropic.Config` struct.

  This function generates a list of HTTP headers necessary for making requests to the Anthropic API, including authentication and content type headers.

  ## Parameters

  - `opts`: The `Anthropic.Config` struct containing configuration options like the API key and the API version.

  ## Returns

  - A list of tuples where each tuple represents an HTTP header. Includes the API key, Anthropic version, and content type headers.

  ## Examples

      iex> Anthropic.HttpClient.Utils.build_header(%Anthropic.Config{api_key: "your_api_key", anthropic_version: "2023-01"})
      [
        {"x-api-key", "your_api_key"},
        {"anthropic-version", "2023-01"},
        {"content-type", "application/json"}
      ]
  """
  def build_header(%Config{api_key: key}) when is_nil(key),
    do: raise(ArgumentError, "Anthropic :api_key can not be nil.")

  def build_header(%Config{} = opts) do
    [
      {"x-api-key", opts.api_key},
      {"anthropic-version", opts.anthropic_version},
      {"content-type", "application/json"}
    ]
  end
end
