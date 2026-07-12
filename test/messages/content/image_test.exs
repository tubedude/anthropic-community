defmodule Anthropic.Messages.Content.ImageTest do
  use ExUnit.Case
  doctest Anthropic.Messages.Content.Image

  alias Anthropic.Messages.Content.Image

  describe "process_image/2" do
    test " with valid base64 png" do
      img =
        File.read("test/images/image.png")
        |> then(fn {:ok, binary} -> binary end)
        |> :base64.encode()

      assert {:ok, %Image{media_type: "image/png", source_type: "base64"}} =
               Image.process_image(img, :base64)
    end

    test " with valid binary png" do
      img =
        File.read("test/images/image.png")
        |> then(fn {:ok, binary} -> binary end)

      assert {:ok, %Image{media_type: "image/png"}} = Image.process_image(img, :binary)
    end

    test "with valid path to png" do
      assert {:ok, %Image{media_type: "image/png"}} =
               Image.process_image("test/images/image.png", :path)
    end

    test "with valid path to jpg" do
      assert {:ok, %Image{media_type: "image/jpeg"}} =
               Image.process_image("test/images/image.jpg", :path)
    end

    test "with valid path to webp" do
      assert {:ok, %Image{media_type: "image/webp"}} =
               Image.process_image("test/images/image.webp", :path)
    end

    test "with valid path to tif" do
      assert {:error,
              "The provided image type image/tiff is not supported. Choose one of: [\"image/jpeg\", \"image/png\", \"image/gif\", \"image/webp\"]"} =
               Image.process_image("test/images/image.tif", :path)
    end

    test "with invalid path to image" do
      assert {:error, "Error reading file enoent path: test/nofile.png"} =
               Image.process_image("test/nofile.png", :path)
    end

    test "with invalid base64" do
      assert {:error, "Invalid base64 data provided for the image."} =
               Image.process_image("nonono", :base64)
    end

    test "with invalid dimension" do
      assert {:error, "The provided image dimensions {1, 1569} are not supported."} =
               Image.process_image(
                 "iVBORw0KGgoAAAANSUhEUgAAAAEAAAYhCAIAAAD0C2PSAAAAHUlEQVR4nO3BMQEAAADCoPVPbQlPoAAAAAAAAP4GGIQAAQlAUEQAAAAASUVORK5CYII=",
                 :base64
               )
    end

    test "rejects a :path file larger than the 5MB limit without reading it into memory" do
      path = Path.join(System.tmp_dir!(), "anthropic_oversized_test_image.bin")
      # Sparse file: seek past the limit and write one byte, no need to allocate 5MB+ for real.
      {:ok, file} = File.open(path, [:write])
      :file.position(file, 5 * 1024 * 1024 + 1)
      IO.binwrite(file, <<0>>)
      File.close(file)

      assert {:error, message} = Image.process_image(path, :path)
      assert message =~ "exceeding the"

      File.rm(path)
    end
  end

  describe "wire encoding" do
    test "round-trips through Anthropic.Messages.Content.to_json/1" do
      {:ok, image} = Image.process_image("test/images/image.png", :path)

      assert %{type: "image", source: %{type: "base64", media_type: "image/png", data: _}} =
               Anthropic.Messages.Content.to_json(image)
    end
  end
end
