defmodule ShipsWeb.LobbyChannel do
  @moduledoc """
  Channel is responsible for finding and joining a game with only 1 player.
  """

  use ShipsWeb, :channel

  alias Ships.Server.GameRegistry
  alias ShipsWeb.Presence

  @impl true
  def join("lobby", _payload, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("join_game", _payload, socket) do
    games = Map.keys(Presence.list("lobby"))

    case games do
      [] ->
        game_id = generate_id()
        Presence.track(self(), "lobby", game_id, %{})
        push(socket, "new_game", %{game_id: game_id})

      _ ->
        game_id = Enum.at(games, 0)
        push(socket, "new_game", %{game_id: game_id})
    end

    {:reply, :ok, socket}
  end

  defp generate_id do
    id =
      :crypto.strong_rand_bytes(10)
      |> Base.encode64()
      |> binary_part(0, 10)

    case GameRegistry.whereis_name(id) do
      :undefined -> id
      _ -> generate_id()
    end
  end
end
