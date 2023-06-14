defmodule ShipsWeb.GameChannel do
  @moduledoc """
  Module is responsible for interaction between the players and the game
  """

  use ShipsWeb, :channel

  alias Ships.Server.GameServer
  alias ShipsWeb.Presence

  intercept ["message", "modal_msg"]

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
        {opponent_status, opponent_ships} =
          GameServer.player_status(game_id, get_opponent_num(player_num))

        {player_status, players_ships} = GameServer.player_status(game_id, player_num)
        Presence.track(self(), "game:" <> game_id, player_num, %{id: player_id})
        {:ok, ship_size} = GameServer.get_next_ship(game_id, player_num)

        push(socket, "place_ship", %{size: ship_size})

        push(socket, "message", %{
          recipient: player_num,
          message: "Place 10 ships on your board.",
          type: "info"
        })

        broadcast(socket, "opponent_update", %{
          recipient: get_opponent_num(player_num),
          status: player_status,
          ships: players_ships
        })

        broadcast(socket, "opponent_update", %{
          recipient: player_num,
          status: opponent_status,
          ships: opponent_ships
        })

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

      broadcast(socket, "message", %{
        recipient: "both",
        message: "The game has started. Good luck!",
        type: "info"
      })

      broadcast(socket, "game_started", %{})
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

    {status, ships_placed} = GameServer.player_status(game_id, player_num)

    case result do
      :ok ->
        push(socket, "place_ship", %{size: next_ship_size})
        push(socket, "ship_placed", %{coordinates: ship_coordinates})

        broadcast(socket, "opponent_update", %{
          recipient: get_opponent_num(player_num),
          status: status,
          ships: ships_placed
        })

      :invalid_coordinates ->
        push(socket, "message", %{
          recipient: player_num,
          message: "You can't place ship here.",
          type: "error"
        })

        push(socket, "place_ship", %{size: next_ship_size})

      :all_placed ->
        push(socket, "message", %{
          recipient: player_num,
          message: "You already placed all of your ships.",
          type: "error"
        })

      :last_placed ->
        send(self(), {:last_placed, game_id})

        push(socket, "message", %{
          recipient: player_num,
          message: "All of your ships have been placed. Wait for the game to begin.",
          type: "info"
        })

        push(socket, "ship_placed", %{last: "true", coordinates: ship_coordinates})

        broadcast(socket, "opponent_update", %{
          recipient: get_opponent_num(player_num),
          status: status,
          ships: ships_placed
        })
    end

    {:reply, :ok, socket}
  end

  def handle_in("place_ship", _payload, socket) do
    game_id = id_from_topic(socket.topic)
    player_num = socket.assigns.player_num
    {_response, next_ship_size} = GameServer.get_next_ship(game_id, player_num)

    push(socket, "message", %{
      recipient: player_num,
      message: "Something wen't wrong. Try again.",
      type: "error"
    })

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
      response == :hit ->
        broadcast(socket, "board_update", %{
          result: response,
          shooter: player_num,
          coordinates: coordinates
        })

        broadcast(socket, "message", %{
          recipient: player_num,
          message: "You hit the ship! It's your turn again.",
          type: "good"
        })

        broadcast(socket, "message", %{
          recipient: get_opponent_num(player_num),
          message: "Oh no, enemy hit your ship! It's his turn again.",
          type: "bad"
        })

        broadcast(socket, "next_turn", %{turn: next_turn})

      response == :destroyed ->
        broadcast(socket, "board_update", %{
          result: response,
          shooter: player_num,
          coordinates: coordinates
        })

        broadcast(socket, "message", %{
          recipient: player_num,
          message: "Congratulations! You destroyed the ship. It's your turn again.",
          type: "good"
        })

        broadcast(socket, "message", %{
          recipient: get_opponent_num(player_num),
          message: "Your ship was destroyed! It's enemy's turn again.",
          type: "bad"
        })

        broadcast(socket, "next_turn", %{turn: next_turn})

      response == :used ->
        push(socket, "message", %{
          recipient: player_num,
          message: "You've already shot at this cell. Choose another one.",
          type: "error"
        })

        push(socket, "next_turn", %{turn: next_turn})

      response == :not_your_turn ->
        push(socket, "message", %{
          recipient: player_num,
          message: "You can't do that, wait for your turn.",
          type: "error"
        })

      response == :miss ->
        broadcast(socket, "board_update", %{
          result: response,
          shooter: player_num,
          coordinates: coordinates
        })

        broadcast(socket, "message", %{
          recipient: player_num,
          message: "You missed! Now it's the enemy's turn",
          type: "bad"
        })

        broadcast(socket, "message", %{
          recipient: get_opponent_num(player_num),
          message: "Enemy missed! Now it's your turn.",
          type: "good"
        })

        broadcast(socket, "next_turn", %{turn: next_turn})

      response == :game_over ->
        broadcast(socket, "board_update", %{
          result: response,
          shooter: player_num,
          coordinates: coordinates
        })

        broadcast(socket, "modal_msg", %{
          recipient: player_num,
          message: "Congratulations, you won!"
        })

        broadcast(socket, "modal_msg", %{
          recipient: get_opponent_num(player_num),
          message: "You lost, try again."
        })
    end

    {:reply, :ok, socket}
  end

  def handle_in("shoot", _payload, socket) do
    game_id = id_from_topic(socket.topic)
    next_turn = GameServer.get_next_turn(game_id)
    player_num = socket.assigns.player_num

    push(socket, "message", %{
      recipient: player_num,
      message: "Something wen't wrong. Try again.",
      type: "error"
    })

    push(socket, "next_turn", %{turn: next_turn})

    {:reply, :ok, socket}
  end

  @impl true
  def handle_out("message", payload, socket) do
    if payload.recipient == socket.assigns.player_num || payload.recipient == "both" do
      push(socket, "message", %{message: payload.message, type: payload.type})
    end

    {:noreply, socket}
  end

  @impl true
  def handle_out("modal_msg", payload, socket) do
    if payload.recipient == socket.assigns.player_num || payload.recipient == "both" do
      push(socket, "modal_msg", %{message: payload.message})
    end

    {:noreply, socket}
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

  defp get_opponent_num(player_num) do
    case player_num do
      :player1 -> :player2
      :player2 -> :player1
    end
  end
end
