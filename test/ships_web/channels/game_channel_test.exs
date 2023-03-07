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
end
