defmodule Ships.Server.ChannelWatcherTest do
  use ShipsWeb.ChannelCase

  alias Ships.Server.ChannelWatcher
  alias Ships.Server.GameServer

  describe "monitor(server_name, topic)" do
    setup [:player1_join, :player2_join]

    test "it subscribes to given topic and receives messages for that topic", context do
      topic = "game:" <> context.game_id
      {:ok, pid} = ChannelWatcher.start_link(:test_watcher)
      ChannelWatcher.monitor(:test_watcher, topic)
      :erlang.trace(pid, true, [:receive])

      ShipsWeb.Endpoint.broadcast(topic, "test_msg", %{
        message: "test message"
      })

      assert_receive {:trace, ^pid, :receive,
                      %Phoenix.Socket.Broadcast{
                        event: "test_msg",
                        payload: %{message: "test message"}
                      }}
    end
  end

  describe "when there are 2 players subscribed to topic and on of them unsubscribes or leaves the game" do
    setup [:player1_join, :player2_join]

    test "it terminates game with game_id from topic", context do
      topic = "game:" <> context.game_id
      {:ok, pid} = ChannelWatcher.start_link(:test_watcher)
      ChannelWatcher.monitor(:test_watcher, topic)
      Process.flag(:trap_exit, true)
      :erlang.trace(pid, true, [:receive])

      assert Process.alive?(context.pid) == true

      leave(context.socket)
      :timer.sleep(200)

      assert Process.alive?(context.pid) == false
    end

    test "it receives message with 'presence_diff' event when on of players leaves", context do
      topic = "game:" <> context.game_id
      {:ok, pid} = ChannelWatcher.start_link(:test_watcher)
      ChannelWatcher.monitor(:test_watcher, topic)
      Process.flag(:trap_exit, true)
      :erlang.trace(pid, true, [:receive])
      leave(context.socket)

      assert_receive {:trace, ^pid, :receive,
                      %Phoenix.Socket.Broadcast{
                        topic: ^topic,
                        event: "presence_diff"
                      }}
    end
  end

  describe "demonitor(server_name, topic)" do
    setup [:player1_join, :player2_join]

    test "it unsubscribes from given topic and does not receive messages for that topic",
         context do
      topic = "game:" <> context.game_id
      {:ok, pid} = ChannelWatcher.start_link(:test_watcher)
      ChannelWatcher.monitor(:test_watcher, topic)
      :erlang.trace(pid, true, [:receive])

      ShipsWeb.Endpoint.broadcast(topic, "test_msg", %{
        message: "test message"
      })

      assert_receive {:trace, ^pid, :receive,
                      %Phoenix.Socket.Broadcast{
                        event: "test_msg",
                        payload: %{message: "test message"}
                      }}

      ChannelWatcher.demonitor(:test_watcher, topic)
      flush_messages()

      ShipsWeb.Endpoint.broadcast(topic, "test_msg2", %{
        message: "test message2"
      })

      refute_receive {:trace, ^pid, :receive,
                      %Phoenix.Socket.Broadcast{
                        event: "test_msg2",
                        payload: %{message: "test message2"}
                      }}
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

  defp flush_messages() do
    receive do
      _ ->
        flush_messages()
    after
      100 -> :ok
    end
  end
end
