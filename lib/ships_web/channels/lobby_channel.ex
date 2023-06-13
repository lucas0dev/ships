defmodule ShipsWeb.LobbyChannel do
  @moduledoc """
  Channel is responsible for creating new game or finding and joining a game with only 1 player.
  """

  use ShipsWeb, :channel

  alias Ships.Server.ChannelWatcher
  alias Ships.Server.GameServer
  alias ShipsWeb.Presence

  @impl true
  def join("lobby", _payload, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("find_game", _payload, socket) do
    games = Map.keys(Presence.list("lobby"))

    case games do
      [] ->
        {:ok, game_id, _pid} = GameServer.new_game()
        pid = :erlang.pid_to_list(self())
        Presence.track(self(), "lobby", game_id, %{pid: pid})
        ChannelWatcher.monitor(:watcher, "game:" <> game_id)
        push(socket, "game_found", %{player: "player1", game_id: game_id})

      _ ->
        game_id = Enum.at(games, 0)
        %{metas: [metas]} = Presence.get_by_key("lobby", game_id)
        game_pid = :erlang.list_to_pid(metas.pid)
        Presence.untrack(game_pid, "lobby", game_id)

        push(socket, "game_found", %{player: "player2", game_id: game_id})
    end

    {:reply, :ok, socket}
  end
end
