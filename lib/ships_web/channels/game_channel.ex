defmodule ShipsWeb.GameChannel do
  @moduledoc """
  Module is responsible for interaction between the players and the game
  """

  use ShipsWeb, :channel

  alias Ships.Server.GameServer
  alias ShipsWeb.Presence

  @impl true
  def join("game:" <> game_id, _payload, socket) do
    send(self(), {:after_join, game_id})
    {:ok, socket}
  end

  @impl true
  def handle_info({:after_join, game_id}, socket) do
    player_id = socket.assigns.user_id

    with {:ok, player_num} <- assign_player(game_id),
         :ok <- GameServer.join_game(game_id, player_id) do
      Presence.track(self(), "game:" <> game_id, player_num, %{id: player_id})

      push(socket, "assign_player", %{player: Atom.to_string(player_num)})
      broadcast(socket, "player_joined", %{player: Atom.to_string(player_num)})
    else
      _ -> push(socket, "unable_to_join", %{})
    end

    {:noreply, socket}
  end

  defp assign_player(game_id) do
    game = Presence.list("game:" <> game_id)

    with true <- game != %{},
         1 <- length(Map.keys(game)) do
      {:ok, :player2}
    else
      false -> {:ok, :player1}
      _ -> {:error, Map.keys(game)}
    end
  end
end
