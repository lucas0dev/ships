defmodule Ships.Core.Player do
  @enforce_keys [:id]
  defstruct id: "",
            status: :preparing,
            ships: [],
            available_ships: [4, 3, 3, 2, 2, 2, 1, 1, 1, 1],
            shot_at: [],
            hit_coordinates: []
end
