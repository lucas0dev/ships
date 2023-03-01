defmodule Ships.Server.GameSupervisor do
  @moduledoc false
  use DynamicSupervisor

  def start_child(game_id, player_id) do
    spec = {Ships.Server.GameServer, game_id: game_id, player_id: player_id}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  def terminate_child(pid) do
    :ok = DynamicSupervisor.terminate_child(__MODULE__, pid)
  end

  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
