defmodule Anthropic.Messages.Message do
  @moduledoc """
  A message returned by the Anthropic Messages API — the `{:ok, message}` result of
  `Anthropic.Messages.create/2` or the final fold of `Anthropic.Messages.stream/2`.
  """

  alias Anthropic.Messages.Content
  alias Anthropic.Messages.Content.ToolUse

  defstruct [
    :id,
    :type,
    :role,
    :model,
    :stop_reason,
    :stop_sequence,
    content: [],
    usage: %{}
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          type: String.t() | nil,
          role: String.t() | nil,
          content: list(Content.t()),
          model: String.t() | nil,
          stop_reason: String.t() | nil,
          stop_sequence: String.t() | nil,
          usage: map()
        }

  @spec from_json(map()) :: t()
  def from_json(body) when is_map(body) do
    %__MODULE__{
      id: body["id"],
      type: body["type"],
      role: body["role"],
      content: Enum.map(body["content"] || [], &Content.from_json/1),
      model: body["model"],
      stop_reason: body["stop_reason"],
      stop_sequence: body["stop_sequence"],
      usage: body["usage"] || %{}
    }
  end

  @doc """
  Converts this message into a plain map suitable for the `messages` request param, for
  continuing a conversation (tool-use loop, multi-turn chat).
  """
  @spec to_param(t()) :: map()
  def to_param(%__MODULE__{role: role, content: content}) do
    %{role: role, content: Enum.map(content, &Content.to_json/1)}
  end

  @doc "True if this message is asking the caller to run tools."
  @spec tool_use?(t()) :: boolean()
  def tool_use?(%__MODULE__{stop_reason: "tool_use"}), do: true
  def tool_use?(%__MODULE__{}), do: false

  @doc "All `tool_use` content blocks in this message, in order."
  @spec tool_uses(t()) :: list(ToolUse.t())
  def tool_uses(%__MODULE__{content: content}) do
    Enum.filter(content, &match?(%ToolUse{}, &1))
  end
end
