defmodule Ships.Core.Ship do
  @moduledoc false
  @enforce_keys [:coordinates, :direction]
  defstruct coordinates: [], direction: ""

  @all_sizes [1, 2, 3, 4]
  @directions [:vertical, :horizontal]
  @type size :: 1 | 2 | 3 | 4

  @type t :: %__MODULE__{
          coordinates: list(),
          direction: atom()
        }

  @spec new({non_neg_integer(), non_neg_integer()}, size(), :horizontal | :vertical) ::
          {:ok, %__MODULE__{}} | :error
  def new({x, y}, size, direction)
      when is_integer(x) and is_integer(y) and size in @all_sizes and direction in @directions do
    coordinates =
      case direction do
        :horizontal -> for i <- 0..(size - 1), do: {x + i, y}
        :vertical -> for i <- 0..(size - 1), do: {x, y + i}
      end

    {:ok, %__MODULE__{coordinates: coordinates, direction: direction}}
  end

  def new(_, _, _) do
    :error
  end
end
