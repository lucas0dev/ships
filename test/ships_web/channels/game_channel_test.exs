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

    test "pushes event 'assign_player' with player assignment" do
      assert_push "assign_player", %{player: "player1"}
    end

    test "broadcasts event 'player_joined' with player assignment" do
      assert_broadcast "player_joined", %{player: "player1"}
    end
  end

  describe "joining channel if player1 already joined game" do
    setup [:player1_join, :player2_join]

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

    test "pushes event 'assign_player' with player assignment" do
      assert_push "assign_player", %{player: "player1"}
    end

    test "broadcasts event 'player_joined' with player assignment" do
      assert_broadcast "player_joined", %{player: "player1"}
    end
  end

  describe "joining channel if 2 players already joined game" do
    setup [:player1_join, :player2_join]

    test "pushes event 'unable_to_join'", %{game_id: game_id} do
      {:ok, socket} = connect(ShipsWeb.UserSocket, %{}, %{})
      {:ok, _, _socket} = subscribe_and_join(socket, "game:" <> game_id, %{})

      assert_push "unable_to_join", %{}
    end
  end

  describe "get_next_ship when player has ships to place" do
    setup [:player1_join]

    test "should push 'place_ship' with ship_size as payload", %{socket: socket} do
      push(socket, "get_next_ship", %{})

      assert_push "place_ship", %{size: ship_size}
      assert is_integer(ship_size) == true
    end
  end

  describe "get_next_ship when player has already placed all of his ships" do
    setup [:player1_join, :place_all_ships_p1]

    test "should push 'message' with information about it as payload", %{socket: socket} do
      push(socket, "get_next_ship", %{})

      assert_push "message", %{message: msg}
      assert msg == "You already placed all of your ships."
    end
  end

  defp player1_join(_context) do
    {:ok, socket} = connect(ShipsWeb.UserSocket, %{}, %{})
    {:ok, game_id, pid} = GameServer.new_game()
    {:ok, _, socket} = subscribe_and_join(socket, "game:" <> game_id, %{})

    %{socket: socket, pid: pid, game_id: game_id}
  end

  defp player2_join(context) do
    {:ok, socket2} = connect(ShipsWeb.UserSocket, %{}, %{})
    player2_id = socket2.assigns.user_id
    {:ok, _, socket2} = subscribe_and_join(socket2, "game:" <> context.game_id, %{})

    %{socket2: socket2, player2_id: player2_id}
  end

  defp place_all_ships_p1(context) do
    place_ships(context, context.socket.assigns.user_id)
  end

  defp place_ships(context, player_id) do
    game = :sys.get_state(context.pid)

    {player_num, player} =
      cond do
        player_id == game.player1.id ->
          {:player1, %{game.player1 | available_ships: [1], ships: [{0, 0}]}}

        player_id == game.player2.id ->
          {:player1, %{game.player1 | available_ships: [1], ships: [{0, 0}]}}
      end

    game = %{game | player_num => player}

    :sys.replace_state(context.pid, fn _state -> game end)

    :ok
  end
end
