defmodule Ships.Server.GameSupervisor do
  @moduledoc false
  use DynamicSupervisor

  def start_child(supervisor, game_id, player_id) do
    spec = {Ships.Server.GameServer, game_id: game_id, player_id: player_id}
    DynamicSupervisor.start_child(supervisor, spec)
  end

  def terminate_child(supervisor, pid) do
    DynamicSupervisor.terminate_child(supervisor, pid)
  end

  def start_link(opts) do
    name = Keyword.get(opts, :name, __MODULE__)
    DynamicSupervisor.start_link(__MODULE__, [], name: name)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
