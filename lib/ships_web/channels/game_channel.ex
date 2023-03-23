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

    socket =
      with {:ok, player_num} <- assign_player(game_id),
           :ok <- GameServer.join_game(game_id, player_id) do
        Presence.track(self(), "game:" <> game_id, player_num, %{id: player_id})
        {:ok, ship_size} = GameServer.get_next_ship(game_id, player_num)
        push(socket, "place_ship", %{size: ship_size})
        broadcast(socket, "player_joined", %{player: Atom.to_string(player_num)})
        assign(socket, :player_num, player_num)
      else
        _ ->
          push(socket, "unable_to_join", %{})
          socket
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
    game_id = id_from_topic(socket.topic)
    player_num = socket.assigns.player_num
    coordinates = {x, y}
    orientation = String.to_atom(orientation)

    {result, ship_coordinates} =
      GameServer.place_ship(game_id, player_num, coordinates, orientation)

    ship_coordinates = for coordinates <- ship_coordinates, do: Tuple.to_list(coordinates)
    {_response, next_ship_size} = GameServer.get_next_ship(game_id, player_num)

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

        push(socket, "ship_placed", %{last: "true", coordinates: ship_coordinates})
    end

    {:reply, :ok, socket}
  end

  def handle_in("place_ship", _payload, socket) do
    game_id = id_from_topic(socket.topic)
    player_num = socket.assigns.player_num
    {_response, next_ship_size} = GameServer.get_next_ship(game_id, player_num)

    push(socket, "message", %{message: "Something wen't wrong. Try again."})
    push(socket, "place_ship", %{size: next_ship_size})

    {:reply, :ok, socket}
  end

  @impl true
  def handle_in("shoot", %{"x" => x, "y" => y}, socket) when is_integer(x) and is_integer(y) do
    game_id = id_from_topic(socket.topic)
    player_num = socket.assigns.player_num
    coordinates = {x, y}

    {response, next_turn, response_coordinates} =
      GameServer.shoot(game_id, player_num, coordinates)

    coordinates = transform_coordinates(response_coordinates)

    cond do
      response in [:hit, :destroyed] ->
        broadcast(socket, "board_update", %{
          result: response,
          shooter: player_num,
          coordinates: coordinates
        })

        broadcast(socket, "next_turn", %{turn: next_turn})

      response == :used ->
        push(socket, "message", %{
          message: "You've already shot at this cell. Choose another one."
        })

        push(socket, "next_turn", %{turn: next_turn})

      response == :not_your_turn ->
        push(socket, "message", %{message: "You can't do that, wait for your turn."})

      response == :miss ->
        broadcast(socket, "board_update", %{
          result: response,
          shooter: player_num,
          coordinates: coordinates
        })

        broadcast(socket, "next_turn", %{turn: next_turn})

      response == :game_over ->
        broadcast(socket, "board_update", %{
          result: response,
          shooter: player_num,
          coordinates: coordinates
        })
    end

    {:reply, :ok, socket}
  end

  def handle_in("shoot", _payload, socket) do
    game_id = id_from_topic(socket.topic)
    next_turn = GameServer.get_next_turn(game_id)

    push(socket, "message", %{message: "Something wen't wrong. Try again."})
    push(socket, "next_turn", %{turn: next_turn})

    {:reply, :ok, socket}
  end

  defp transform_coordinates(coordinates) do
    for {x, y} <- coordinates, do: [x, y]
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

  defp id_from_topic(topic) do
    String.replace(topic, "game:", "")
  end
end
