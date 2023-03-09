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

  describe "find_game when there are none game_ids tracked by Presence" do
    test "replies with status ok", %{socket: socket} do
      ref = push(socket, "find_game", %{})
      assert_reply ref, :ok
    end

    test "pushes event 'game_found' with generated game_id", %{socket: socket} do
      push(socket, "find_game", %{})
      assert_push "game_found", %{game_id: _game_id}
    end

    test "makes Presence track socket with game_id", %{socket: socket} do
      ref = push(socket, "find_game", %{})
      assert_push "game_found", %{game_id: game_id}
      assert_reply ref, :ok
      presence_list = Presence.list("lobby")

      assert Map.has_key?(presence_list, game_id)
    end

    test "makes Presence keep pid of process that created a game", %{socket: socket} do
      ref = push(socket, "find_game", %{})
      assert_push "game_found", %{game_id: game_id}
      assert_reply ref, :ok
      %{metas: [metas]} = Presence.get_by_key("lobby", game_id)
      game_pid = :erlang.list_to_pid(metas.pid)

      assert Process.alive?(game_pid) == true
    end
  end

  describe "find_game when there is already game tracked by Presence" do
    setup [:player1_find_game, :player2_find_game]

    test "replies with status ok", %{ref: ref} do
      assert_reply ref, :ok
    end

    test "pushes event 'game_found' with existing game_id", %{game_id: game_id, ref: ref} do
      assert_reply ref, :ok
      assert_push "game_found", %{game_id: ^game_id}
    end

    test "makes Presence untrack process that created a new game", %{game_id: game_id, ref: ref} do
      assert_reply ref, :ok
      assert_push "game_found", %{game_id: ^game_id}

      result = Presence.get_by_key("lobby", game_id)

      assert result == []
    end
  end

  def player1_find_game(context) do
    push(context.socket, "find_game", %{})
    assert_push "game_found", %{game_id: game_id}

    %{game_id: game_id}
  end

  def player2_find_game(context) do
    ref = push(context.socket2, "find_game", %{})

    %{ref: ref}
  end
end
