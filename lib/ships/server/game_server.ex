defmodule Ships.Server.GameServer do
  @moduledoc false
  use GenServer

  alias Ships.Core.Game
  alias Ships.Server.GameRegistry

  def start_link(game_id: game_id, player_id: player_id) do
    GenServer.start_link(__MODULE__, player_id, name: via_tuple(game_id))
  end

  @impl true
  def init(player_id) do
    state = Game.new_game(player_id)
    {:ok, state}
  end

  defp via_tuple(game_id) do
    {:via, GameRegistry, game_id}
  end
end
