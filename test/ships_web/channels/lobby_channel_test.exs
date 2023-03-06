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
    ref = push(context.socket, "new_game", %{})

    %{game_id: game_id, ref: ref}
  end

  describe "joining channel" do
    test "should generate and assign user_id string to socket", %{socket: socket} do
      user_id = socket.assigns.user_id

      assert String.length(user_id) > 0 == true
      assert String.valid?(user_id) == true
    end
  end

  describe "new_game when there are none game_ids tracked by Presence" do
    test "replies with status ok", %{socket: socket} do
      ref = push(socket, "new_game", %{})
      assert_reply ref, :ok
    end

    test "pushes event 'game_created' with generated game_id", %{socket: socket} do
      push(socket, "new_game", %{})
      assert_push "game_created", %{game_id: _game_id}
    end

    test "makes Presence track socket with game_id", %{socket: socket} do
      ref = push(socket, "new_game", %{})
      assert_push "game_created", %{game_id: game_id}
      assert_reply ref, :ok
      presence_list = Presence.list("lobby")

      assert Map.has_key?(presence_list, game_id)
    end
  end

  describe "new_game when there is already game tracked by Presence" do
    setup [:track_player]

    test "replies with status ok", %{ref: ref} do
      assert_reply ref, :ok
    end

    test "should not track and generate new game_id", %{game_id: game_id, ref: ref} do
      assert_push "game_created", %{game_id: ^game_id}
      assert_reply ref, :ok

      presence_list = Presence.list("lobby")

      assert Map.has_key?(presence_list, game_id)
    end

    test "pushes event 'new_game' with existing game_id", %{game_id: game_id, ref: ref} do
      assert_reply ref, :ok
      assert_push "game_created", %{game_id: ^game_id}
    end
  end
end
