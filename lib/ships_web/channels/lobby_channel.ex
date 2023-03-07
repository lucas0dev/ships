defmodule ShipsWeb.LobbyChannel do
  @moduledoc """
  Channel is responsible for finding and joining a game with only 1 player.
  """

  use ShipsWeb, :channel

  alias Ships.Server.GameServer
  alias ShipsWeb.Presence

  @impl true
  def join("lobby", _payload, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("new_game", _payload, socket) do
    games = Map.keys(Presence.list("lobby"))

    case games do
      [] ->
        {:ok, game_id, _pid} = GameServer.new_game()
        Presence.track(self(), "lobby", game_id, %{})
        push(socket, "game_created", %{game_id: game_id})

      _ ->
        game_id = Enum.at(games, 0)
        push(socket, "game_created", %{game_id: game_id})
    end

    {:reply, :ok, socket}
  end
end
