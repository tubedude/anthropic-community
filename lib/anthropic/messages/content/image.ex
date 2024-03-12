defmodule Anthropic.Messages.Content.Image do
  @moduledoc """
  A module dedicated to processing image content within the [Anthropic ecosystem](https://docs.anthropic.com/claude/docs/vision).
  This module offers functionality for validating, processing, and converting images to
  base64 encoded strings, ensuring they meet specific criteria such as supported file types
  and dimensions.

  ## Features

  - Supports multiple image formats: JPEG, PNG, GIF, and WEBP.
  - Validates images against a set of predefined dimensions and aspect ratios.
  - Converts images to a base64 encoded string for easy transmission and storage.
  - Provides detailed error handling for various failure scenarios during image processing.

  ## Usage

  The primary entry point to the module is the `process_image/2` function, which takes an image input
  and an input type. The image input can be specified as a binary data, a file path, or a base64 encoded string.
  The function returns a structured map with the image's metadata and base64 encoded content if successful,
  or an error message if not.

  ### Supported Input Types

  - `:binary` - Direct binary data of the image.
  - `:path` - A file system path to the image.
  - `:base64` - A base64 encoded string of the image.

  ### Example

      Anthropic.Messages.Content.Image.process_image("/path/to/image.png", :path)

  This function returns an `{:ok, response}` tuple on success, where `response` is a map that includes the type,
  source type, media type, and base64 data of the image. On failure, it returns `{:error, error_message}`.
  """

  @supported_types ["image/jpeg", "image/png", "image/gif", "image/webp"]
  @supported_sizes [
    {"1:1", {1092, 1092}},
    {"3:4", {951, 1268}},
    {"2:3", {896, 1344}},
    {"9:16", {819, 1456}},
    {"1:2", {784, 1568}}
  ]

  @type input_type :: :binary | :path | :base64
  @type mime_type :: String.t()
  @type dimensions :: {integer, integer}
  @type supported_size :: {String.t(), dimensions}
  @type image_input :: binary | String.t()
  @type process_output :: {:ok, response()} | {:error, String.t()}
  @type response :: %{
          type: String.t(),
          source: %{
            type: String.t(),
            media_type: String.t(),
            data: binary()
          }
        }

  @spec process_image(image_input(), input_type()) :: process_output()
  @doc """
  Processes the given image input based on the specified input type and converts it into a base64 encoded string.

  ## Parameters

  - `image_input`: The image input, which can be binary data, a file path, or a base64 encoded string.
  - `input_type`: A symbol indicating the type of the `image_input` (`:binary`, `:path`, `:base64`).

  ## Returns

  An `{:ok, response}` tuple containing the processed image information or `{:error, reason}` on failure.
  """
  def process_image(image_input, input_type) do
    with {:ok, image_binary} <- read_image({input_type, image_input}),
         {:ok, image_binary, mime_type} <- valid_image(image_binary),
         {:ok, base64_data} <- image_to_base64(image_binary) do
      {:ok, build_response_object(mime_type, base64_data)}
    else
      {:error, :invalid_base64} ->
        {:error, "Invalid base64 data provided for the image."}

      {:error, {:unsupported_type, type}} ->
        {:error,
         "The provided image type #{type} is not supported. Choose one of: #{inspect(@supported_types)}"}

      {:error, {:unsupported_dimensions, dims}} ->
        {:error, "The provided image dimensions #{inspect(dims)} are not supported."}

      {:error, :no_image_info} ->
        {:error, "Could not extract image information. The file may not be a valid image."}

      {:error, :unknown_error} ->
        {:error, "An unknown error occurred during image processing."}

      {:error, {:file_error, reason, path}} ->
        {:error, "Error reading file #{reason} path: #{path}"}

      {:error, reason} ->
        {:error, "Error occurred: #{inspect(reason)}"}

      _error ->
        {:error, "An unspecified error occurred during image processing."}
    end
  end

  defp read_image({:binary, image_binary}) do
    {:ok, image_binary}
  end

  defp read_image({:path, image_path}) do
    case File.read(image_path) do
      {:ok, _file} = success -> success
      {:error, reason} -> {:error, {:file_error, reason, image_path}}
    end
  end

  defp read_image({:base64, image_base64}) do
    case Base.decode64(image_base64, ignore: :whitespace) do
      {:ok, binary_data} -> {:ok, binary_data}
      :error -> {:error, :invalid_base64}
    end
  end

  defp image_to_base64(image_binary) when is_binary(image_binary) do
    base64_data = :base64.encode(image_binary)
    {:ok, base64_data}
  end

  defp build_response_object(mime_type, base64_data) do
    %{
      type: "image",
      source: %{
        type: "base64",
        media_type: mime_type,
        data: base64_data
      }
    }
  end

  defp valid_image(image_binary) when is_binary(image_binary) do
    with {:image_info, {mime_type, width, height, _variant}} <-
           {:image_info, ExImageInfo.info(image_binary)},
         {:ok, mime_type} <- validate_mime_type(mime_type),
         {:ok, true} <- verify_image_size(width, height) do
      {:ok, image_binary, mime_type}
    else
      {:image_info, var} -> {:error, "no_image_info: #{inspect(var)}"}
      {:error, {:unsupported_type, _mime_type}} = error -> error
      {:error, {:unsupported_dimensions, _}} = error -> error
      _ -> {:error, :unknown_error}
    end
  end

  defp verify_image_size(width, height) do
    if Enum.any?(@supported_sizes, fn {_ratio, {max_width, max_height}} ->
         width <= max_width and height <= max_height
       end) do
      {:ok, true}
    else
      {:error, {:unsupported_dimensions, {width, height}}}
    end
  end

  defp validate_mime_type(mime_type) do
    if Enum.member?(@supported_types, mime_type) do
      {:ok, mime_type}
    else
      {:error, {:unsupported_type, mime_type}}
    end
  end
end
