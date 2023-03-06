defmodule ShipsWeb.LobbyChannelTest do
  use ShipsWeb.ChannelCase

  alias ShipsWeb.Presence
  alias ShipsWeb.UserSocket

  setup do
    {:ok, socket} = connect(UserSocket, %{}, %{})
    {:ok, _, socket} = subscribe_and_join(socket, "lobby")
    {:ok, socket2} = connect(UserSocket, %{}, %{})
    {:ok, _, socket2} = subscribe_and_join(socket2, "lobby")

    %{socket: socket, socket2: socket2}
  end

  def track_player(context) do
    game_id = "new_game"
    Presence.track(context.socket2, game_id, %{})
    ref = push(context.socket, "join_game", %{})

    %{game_id: game_id, ref: ref}
  end

  describe "join_game when there are none game_ids tracked by Presence" do
    test "replies with status ok", %{socket: socket} do
      ref = push(socket, "join_game", %{})
      assert_reply ref, :ok
    end

    test "pushes event 'new_game' with generated game_id", %{socket: socket} do
      push(socket, "join_game", %{})
      assert_push "new_game", %{game_id: _game_id}
    end

    test "makes Presence track socket with game_id", %{socket: socket} do
      ref = push(socket, "join_game", %{})
      assert_push "new_game", %{game_id: game_id}
      assert_reply ref, :ok
      presence_list = Presence.list("lobby")

      assert Map.has_key?(presence_list, game_id)
    end
  end

  describe "join_game when there is already game tracked by Presence" do
    setup [:track_player]

    test "replies with status ok", %{ref: ref} do
      assert_reply ref, :ok
    end

    test "should not track and generate new game_id", %{game_id: game_id, ref: ref} do
      assert_push "new_game", %{game_id: ^game_id}
      assert_reply ref, :ok

      presence_list = Presence.list("lobby")

      assert Map.has_key?(presence_list, game_id)
    end

    test "pushes event 'new_game' with existing game_id", %{game_id: game_id, ref: ref} do
      assert_reply ref, :ok
      assert_push "new_game", %{game_id: ^game_id}
    end
  end
end
