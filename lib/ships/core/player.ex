defmodule Ships.Core.Player do
  @moduledoc false
  @enforce_keys [:id]
  defstruct id: "",
            status: :preparing,
            ships: [],
            available_ships: [4, 3, 3, 2, 2, 2, 1, 1, 1, 1],
            shot_at: [],
            got_hit_at: []

  @type t :: %__MODULE__{
          id: String,
          status: atom(),
          ships: list,
          available_ships: list,
          shot_at: list,
          got_hit_at: list
        }
end
