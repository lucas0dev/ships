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
      {:ok, ship_size} = GameServer.get_next_ship(game_id, player_id)

      push(socket, "place_ship", %{size: ship_size})
      broadcast(socket, "player_joined", %{player: Atom.to_string(player_num)})
    else
      _ -> push(socket, "unable_to_join", %{})
    end

    {:noreply, socket}
  end

  def handle_info({:last_placed, game_id}, socket) do
    if GameServer.game_status(game_id) == :in_progress do
      broadcast(socket, "next_turn", %{turn: :player1})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_in(
        "place_ship",
        %{"x" => x, "y" => y, "orientation" => orientation},
        socket
      )
      when is_integer(x) and is_integer(y) do
    game_id = String.replace(socket.topic, "game:", "")
    player_id = socket.assigns.user_id
    coordinates = {x, y}
    orientation = String.to_atom(orientation)

    {result, ship_coordinates} =
      GameServer.place_ship(game_id, player_id, coordinates, orientation)

    ship_coordinates = for coordinates <- ship_coordinates, do: Tuple.to_list(coordinates)
    {_response, next_ship_size} = GameServer.get_next_ship(game_id, player_id)

    case result do
      :ok ->
        push(socket, "place_ship", %{size: next_ship_size})
        push(socket, "ship_placed", %{coordinates: ship_coordinates})

      :invalid_coordinates ->
        push(socket, "message", %{message: "You can't place ship here."})
        push(socket, "place_ship", %{size: next_ship_size})

      :all_placed ->
        push(socket, "message", %{message: "You already placed all of your ships."})

      :last_placed ->
        send(self(), {:last_placed, game_id})

        push(socket, "message", %{
          message: "All of your ships have been placed. Wait for the game to begin."
        })

        push(socket, "ship_placed", %{coordinates: ship_coordinates})
    end

    {:reply, :ok, socket}
  end

  def handle_in("place_ship", _payload, socket) do
    game_id = String.replace(socket.topic, "game:", "")
    player_id = socket.assigns.user_id
    {_response, next_ship_size} = GameServer.get_next_ship(game_id, player_id)

    push(socket, "message", %{message: "Something wen't wrong. Try again."})
    push(socket, "place_ship", %{size: next_ship_size})

    {:reply, :ok, socket}
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
