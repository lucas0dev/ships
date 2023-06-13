defmodule ShipsWeb.GameChannelTest do
  use ShipsWeb.ChannelCase

  alias Ships.Server.GameServer
  alias ShipsWeb.Presence

  describe "joining channel if noone joined game yet" do
    setup [:player1_join]

    test "should add user to the game as a player1", %{socket: socket, pid: pid} do
      player1_id = socket.assigns.user_id
      state = :sys.get_state(pid)

      assert state.player1.id == player1_id
    end

    test "should make Presence track game:game_id topic with player1 as a key", %{
      socket: socket,
      game_id: game_id
    } do
      user_id = socket.assigns.user_id
      %{"player1" => %{metas: [game_data]}} = Presence.list("game:" <> game_id)

      assert game_data.id == user_id
    end

    test "should store player_num in a socket as :player1", %{socket: socket} do
      assert socket.assigns.player_num == :player1
    end

    test "pushes event 'place_ship' with ship size as a payload" do
      assert_push "place_ship", %{size: size}
      assert is_integer(size) == true
    end

    test "broadcasts 'opponent_update' message with {recipient: :player1, status: _, ships: _} map" do
      assert_broadcast "opponent_update", %{recipient: :player1, status: _, ships: _}
    end

    test "broadcasts 'opponent_update' message with {recipient: :player2, status: _, ships: _} map" do
      assert_broadcast "opponent_update", %{recipient: :player2, status: _, ships: _}
    end
  end

  describe "joining channel if player1 already joined game" do
    setup [:player1_join, :flush_messages, :player2_join]

    test "should add user to the game as a player2", %{socket2: socket2, pid: pid} do
      player2_id = socket2.assigns.user_id
      state = :sys.get_state(pid)

      assert state.player2.id == player2_id
    end

    test "should make Presence track game:game_id topic with player2 as a key", %{
      socket2: socket2,
      game_id: game_id
    } do
      user_id = socket2.assigns.user_id
      %{"player2" => %{metas: [game_data]}} = Presence.list("game:" <> game_id)

      assert game_data.id == user_id
    end

    test "should store player_num in a socket as :player2", %{socket2: socket2} do
      assert socket2.assigns.player_num == :player2
    end

    test "pushes event 'place_ship' with ship size as a payload" do
      assert_push "place_ship", %{size: size}
      assert is_integer(size) == true
    end
  end

  describe "joining channel if 2 players already joined game" do
    setup [:player1_join, :player2_join, :flush_messages]

    test "pushes event 'unable_to_join'", %{game_id: game_id} do
      {:ok, socket} = connect(ShipsWeb.UserSocket, %{}, %{})
      {:ok, _, _socket} = subscribe_and_join(socket, "game:" <> game_id, %{})

      assert_push "unable_to_join", %{}
    end
  end

  describe "handle_in(place_ship) when player can place ship" do
    setup [:player1_join, :flush_messages]

    test "pushes event 'place_ship' with next ship size", %{socket: socket} do
      push(socket, "place_ship", %{"x" => 2, "y" => 2, "orientation" => "horizontal"})

      assert_push "place_ship", %{size: next_ship_size}
      assert is_integer(next_ship_size) == true
    end

    test "pushes event 'ship_placed' with list of ship coordinates", %{socket: socket} do
      push(socket, "place_ship", %{"x" => 2, "y" => 2, "orientation" => "horizontal"})

      assert_push "ship_placed", %{coordinates: ship_coordinates}
      assert is_list(ship_coordinates) == true
    end
  end

  describe "handle_in(place_ship) with invalid or already used coordinates" do
    setup [:player1_join]

    test "pushes event 'place_ship' with next ship size", %{socket: socket} do
      push(socket, "place_ship", %{"x" => 0, "y" => 0, "orientation" => "horizontal"})
      flush_messages()
      push(socket, "place_ship", %{"x" => 0, "y" => 0, "orientation" => "horizontal"})

      assert_push "place_ship", %{size: next_ship_size}
      assert is_integer(next_ship_size) == true
    end

    test "pushes event 'message' with 'You can't place ship here.' message", %{socket: socket} do
      push(socket, "place_ship", %{"x" => 0, "y" => 0, "orientation" => "horizontal"})
      flush_messages()
      push(socket, "place_ship", %{"x" => 0, "y" => 0, "orientation" => "horizontal"})

      assert_push "message", %{message: "You can't place ship here."}
    end
  end

  describe "handle_in(place_ship) when all ships have been already placed" do
    setup [:player1_join, :player2_join, :place_last_ship_p1, :flush_messages]

    test "pushes event 'message' with 'You already placed all of your ships.' message", %{
      socket: socket
    } do
      push(socket, "place_ship", %{"x" => 0, "y" => 0, "orientation" => "horizontal"})
      flush_messages()
      push(socket, "place_ship", %{"x" => 0, "y" => 0, "orientation" => "horizontal"})

      assert_push "message", %{message: "You already placed all of your ships."}
    end
  end

  describe "handle_in(place_ship) when player places his last ship" do
    setup [:player1_join, :player2_join, :flush_messages]

    test "pushes a 'message' event with message that all ships have been placed", %{
      socket: socket
    } do
      push(socket, "place_ship", %{"x" => 2, "y" => 2, "orientation" => "horizontal"})
      x = 4
      y = 4
      push(socket, "place_ship", %{"x" => x, "y" => y, "orientation" => "horizontal"})

      assert_push "message", %{
        message: "All of your ships have been placed. Wait for the game to begin."
      }
    end

    test "pushes event 'ship_placed' with list of ship coordinates", %{socket: socket} do
      push(socket, "place_ship", %{"x" => 2, "y" => 2, "orientation" => "horizontal"})
      flush_messages()
      x = 4
      y = 4
      push(socket, "place_ship", %{"x" => x, "y" => y, "orientation" => "horizontal"})

      assert_push "ship_placed", %{last: "true", coordinates: ship_coordinates}
      assert is_list(ship_coordinates) == true
      assert ship_coordinates == [[x, y], [x + 1, y]]
    end

    test "broadcasts a 'opponent_update' event with %{recipient: :player2, status: _, ships: _} map",
         %{
           socket: socket
         } do
      push(socket, "place_ship", %{"x" => 2, "y" => 2, "orientation" => "horizontal"})
      flush_messages()
      x = 4
      y = 4
      push(socket, "place_ship", %{"x" => x, "y" => y, "orientation" => "horizontal"})

      assert_broadcast "opponent_update", %{
        recipient: :player2,
        status: _,
        ships: _
      }
    end
  end

  describe "handle_in(place_ship) after last ship of both players has been placed" do
    setup [:player1_join, :player2_join, :flush_messages]

    test "broadcasts a 'next_turn' event with information about which player's turn is next", %{
      socket: socket
    } do
      push(socket, "place_ship", %{"x" => 2, "y" => 2, "orientation" => "horizontal"})
      x = 4
      y = 4
      push(socket, "place_ship", %{"x" => x, "y" => y, "orientation" => "horizontal"})

      assert_broadcast "next_turn", %{
        turn: :player1
      }
    end

    test "broadcasts a 'message' event with 'The game has started. Good luck!' message", %{
      socket: socket
    } do
      push(socket, "place_ship", %{"x" => 2, "y" => 2, "orientation" => "horizontal"})
      flush_messages()
      x = 4
      y = 4
      push(socket, "place_ship", %{"x" => x, "y" => y, "orientation" => "horizontal"})

      assert_broadcast "message", %{
        message: "The game has started. Good luck!"
      }
    end

    test "broadcasts a 'game_started' event with empty map", %{
      socket: socket
    } do
      push(socket, "place_ship", %{"x" => 2, "y" => 2, "orientation" => "horizontal"})
      flush_messages()
      x = 4
      y = 4
      push(socket, "place_ship", %{"x" => x, "y" => y, "orientation" => "horizontal"})

      assert_broadcast "game_started", %{}
    end
  end

  describe "handle_in(place_ship) with invalid parameters" do
    setup [:player1_join, :player2_join, :flush_messages]

    test "pushes a 'message' event with 'Something wen't wrong. Try again.' message", %{
      socket: socket
    } do
      push(socket, "place_ship", %{"orientation" => :wrong})

      assert_push "message", %{message: "Something wen't wrong. Try again."}
    end

    test "pushes event 'place_ship' with next ship size", %{socket: socket} do
      push(socket, "place_ship", %{"orientation" => :wrong})

      assert_push "place_ship", %{size: next_ship_size}
      assert is_integer(next_ship_size) == true
    end
  end

  describe "handle_in(shoot) when ship was hit" do
    setup [:player1_join, :player2_join, :place_last_ship_p1, :flush_messages]

    test "should broadcast 'board_update' event with :hit response", %{socket: socket} do
      x = 2
      y = 2
      push(socket, "shoot", %{"x" => x, "y" => y})
      shooter = socket.assigns.player_num

      assert_broadcast "board_update", %{
        result: :hit,
        shooter: ^shooter,
        coordinates: [[^x, ^y]]
      }
    end

    test "should broadcast 'next_turn' event turn: :player1 as a payload", %{socket: socket} do
      x = 2
      y = 2
      push(socket, "shoot", %{"x" => x, "y" => y})
      shooter = socket.assigns.player_num

      assert_broadcast "next_turn", %{
        turn: ^shooter
      }
    end
  end

  describe "handle_in(shoot) when ship was destroyed" do
    setup [:player1_join, :player2_join, :place_last_ship_p1, :flush_messages]

    test "should broadcast 'board_update' event with :destroyed response", %{socket: socket} do
      x = 2
      y = 2
      push(socket, "shoot", %{"x" => x, "y" => y})
      push(socket, "shoot", %{"x" => x + 1, "y" => y})
      shooter = socket.assigns.player_num
      ship_coordinates = [[x, y], [x + 1, y]]

      assert_broadcast "board_update", %{
        result: :destroyed,
        shooter: ^shooter,
        coordinates: ^ship_coordinates
      }
    end

    test "should broadcast 'next_turn' event turn: :player1 as a payload", %{socket: socket} do
      x = 2
      y = 2
      push(socket, "shoot", %{"x" => x, "y" => y})
      push(socket, "shoot", %{"x" => x + 1, "y" => y})
      shooter = socket.assigns.player_num

      assert_broadcast "next_turn", %{
        turn: ^shooter
      }
    end
  end

  describe "handle_in(shoot) when its opposite player turn" do
    setup [:player1_join, :player2_join, :place_last_ship_p1, :flush_messages]

    test "should push 'message' event 'You can't do that, wait for your turn' message", %{
      socket2: socket2
    } do
      x = 2
      y = 2
      push(socket2, "shoot", %{"x" => x, "y" => y})

      assert_push "message", %{message: "You can't do that, wait for your turn."}
    end
  end

  describe "handle_in(shoot) when player didn't hit a ship" do
    setup [:player1_join, :player2_join, :place_last_ship_p1, :flush_messages]

    test "should broadcast 'board_update' event with :miss response", %{socket: socket} do
      x = 5
      y = 5
      push(socket, "shoot", %{"x" => x, "y" => y})
      shooter = socket.assigns.player_num

      assert_broadcast "board_update", %{
        result: :miss,
        shooter: ^shooter,
        coordinates: _coordinates
      }
    end

    test "should broadcast 'next_turn' event turn: :player2 as a payload", %{socket: socket} do
      x = 5
      y = 5
      push(socket, "shoot", %{"x" => x, "y" => y})

      assert_broadcast "next_turn", %{
        turn: :player2
      }
    end
  end

  describe "handle_in(shoot) when player destroyed all of the opponent ships" do
    setup [:player1_join, :player2_join, :place_last_ship_p1, :flush_messages]

    test "should broadcast 'board_update' event with :game_over response", %{socket: socket} do
      push(socket, "shoot", %{"x" => 0, "y" => 0})
      push(socket, "shoot", %{"x" => 2, "y" => 2})
      push(socket, "shoot", %{"x" => 3, "y" => 2})
      shooter = socket.assigns.player_num

      assert_broadcast "board_update", %{
        result: :game_over,
        shooter: ^shooter,
        coordinates: _coordinates
      }
    end
  end

  describe "handle_in(shoot) with invalid parameters" do
    setup [:player1_join, :player2_join, :place_last_ship_p1, :flush_messages]

    test "should push message event with 'Something wen't wrong. Try again.' message", %{
      socket: socket
    } do
      push(socket, "shoot", %{"y" => 2})

      assert_push "message", %{message: "Something wen't wrong. Try again."}
    end

    test "should push next_turn event with next player's turn", %{socket: socket} do
      push(socket, "shoot", %{"y" => 2})

      assert_push "next_turn", %{turn: :player1}
    end
  end

  describe "handle_in(shoot) when player already shot at chosen coordinates" do
    setup [:player1_join, :player2_join, :place_last_ship_p1, :flush_messages]

    test "should push message event with 'You've already shot at this cell. Choose another one.' message",
         %{
           socket: socket
         } do
      push(socket, "shoot", %{"x" => 0, "y" => 0})
      flush_messages()
      push(socket, "shoot", %{"x" => 0, "y" => 0})

      assert_push "message", %{message: "You've already shot at this cell. Choose another one."}
    end

    test "should push next_turn event with next player's turn", %{socket: socket} do
      push(socket, "shoot", %{"x" => 0, "y" => 0})
      flush_messages()
      push(socket, "shoot", %{"x" => 0, "y" => 0})

      assert_push "next_turn", %{turn: :player1}
    end
  end

  defp player1_join(_context) do
    {:ok, socket} = connect(ShipsWeb.UserSocket, %{}, %{})
    {:ok, game_id, pid} = GameServer.new_game()
    {:ok, _, socket} = subscribe_and_join(socket, "game:" <> game_id, %{})

    game = :sys.get_state(pid)
    player1 = %{game.player1 | available_ships: [1, 1, 2], ships: [[{0, 0}]]}
    game = %{game | player1: player1}
    :sys.replace_state(pid, fn _state -> game end)

    %{socket: socket, pid: pid, game_id: game_id}
  end

  defp player2_join(context) do
    {:ok, socket2} = connect(ShipsWeb.UserSocket, %{}, %{})
    player2_id = socket2.assigns.user_id
    {:ok, _, socket2} = subscribe_and_join(socket2, "game:" <> context.game_id, %{})

    game = :sys.get_state(context.pid)

    player2 = %{
      game.player2
      | status: :ready,
        available_ships: [1, 2],
        ships: [[{0, 0}], [{2, 2}, {3, 2}]]
    }

    game = %{game | player2: player2}
    :sys.replace_state(context.pid, fn _state -> game end)

    %{socket2: socket2, player2_id: player2_id}
  end

  defp place_last_ship_p1(context) do
    game = :sys.get_state(context.pid)

    player1 = %{
      game.player1
      | status: :ready,
        available_ships: [1, 1, 1],
        ships: [[{0, 0}], [{2, 2}], [{4, 4}]]
    }

    game = %{game | player1: player1}
    :sys.replace_state(context.pid, fn _state -> game end)
    :ok
  end

  defp flush_messages() do
    receive do
      _ ->
        flush_messages()
    after
      100 -> :ok
    end
  end

  defp flush_messages(_context) do
    flush_messages()
  end
end
