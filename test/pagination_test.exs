defmodule Anthropic.PaginationTest do
  use ExUnit.Case, async: true

  alias Anthropic.{Error, Pagination}

  describe "stream/2" do
    test "walks pages via after_id/last_id until has_more is false" do
      pages = %{
        nil => %{data: [%{"id" => "a"}, %{"id" => "b"}], has_more: true, last_id: "b"},
        "b" => %{data: [%{"id" => "c"}], has_more: false, last_id: "c"}
      }

      fetch = fn opts -> {:ok, Map.fetch!(pages, Keyword.get(opts, :after_id))} end

      assert Pagination.stream([], fetch) |> Enum.to_list() == [
               %{"id" => "a"},
               %{"id" => "b"},
               %{"id" => "c"}
             ]
    end

    test "stops when a page has no last_id even if has_more is true" do
      fetch = fn _opts -> {:ok, %{data: [%{"id" => "a"}], has_more: true, last_id: nil}} end

      assert Pagination.stream([], fetch) |> Enum.to_list() == [%{"id" => "a"}]
    end

    test "stops immediately on an empty first page" do
      fetch = fn _opts -> {:ok, %{data: [], has_more: false, last_id: nil}} end

      assert Pagination.stream([], fetch) |> Enum.to_list() == []
    end

    test "is lazy — only fetches as many pages as consumed" do
      counter = :counters.new(1, [])

      fetch = fn opts ->
        n = :counters.add(counter, 1, 1) |> then(fn _ -> :counters.get(counter, 1) end)
        assert Keyword.get(opts, :after_id, "0") == "#{n - 1}"
        {:ok, %{data: [%{"id" => "#{n}"}], has_more: true, last_id: "#{n}"}}
      end

      Pagination.stream([], fetch) |> Enum.take(3)

      assert :counters.get(counter, 1) == 3
    end

    test "raises the underlying Anthropic.Error when a page fetch fails" do
      fetch = fn _opts -> {:error, Error.new(:api_error, "boom", status: 500)} end

      assert_raise Error, ~r/boom/, fn ->
        Pagination.stream([], fetch) |> Enum.to_list()
      end
    end

    test "preserves caller opts on the first page and forwards after_id on subsequent pages" do
      requests = :counters.new(1, [])

      fetch = fn opts ->
        n = :counters.add(requests, 1, 1) |> then(fn _ -> :counters.get(requests, 1) end)

        if n == 1 do
          assert Keyword.get(opts, :limit) == 10
          refute Keyword.has_key?(opts, :after_id)
          {:ok, %{data: [%{"id" => "a"}], has_more: true, last_id: "a"}}
        else
          assert Keyword.get(opts, :after_id) == "a"
          assert Keyword.get(opts, :limit) == 10
          {:ok, %{data: [%{"id" => "b"}], has_more: false, last_id: "b"}}
        end
      end

      assert Pagination.stream([limit: 10], fetch) |> Enum.to_list() == [
               %{"id" => "a"},
               %{"id" => "b"}
             ]
    end
  end
end
