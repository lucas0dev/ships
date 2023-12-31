defmodule Ships.Server.GameServerTest do
  use ExUnit.Case

  alias Ships.Core.Game
  alias Ships.Server.GameServer
  alias Ships.Server.GameSupervisor

  setup do
    {:ok, pid} = start_supervised({GameSupervisor, [name: :game_supervisor]})
    %{supervisor: pid}
  end

  describe "new_game(supervisor)" do
    test "should start a process with Game struct as a state", context do
      {:ok, _game_id, pid} = GameServer.new_game(context.supervisor)

      assert %Game{} = :sys.get_state(pid)
    end

    test "should return {:ok, game_id, pid}", context do
      assert {:ok, _game_id, _pid} = GameServer.new_game(context.supervisor)
    end
  end

  describe "terminate(game_id) when process with given game_id exists" do
    setup [:create_game]

    test "should terminate game process with given game_id and return :ok", context do
      response = GameServer.terminate(context.supervisor, context.game_id)

      assert response == :ok
      assert false == Process.alive?(context.pid)
    end
  end

  describe "terminate(game_id) when process with given game_id does not exist" do
    setup [:create_game]

    test "should return :error", context do
      response = GameServer.terminate(context.supervisor, "not_existing_id")

      assert response == :error
    end
  end

  defp create_game(context) do
    player1_id = "player1"
    player2_id = "player2"
    {:ok, game_id, pid} = GameServer.new_game(context.supervisor)
    :ok = GameServer.join_game(game_id, player1_id)

    %{
      pid: pid,
      player1_id: player1_id,
      player2_id: player2_id,
      game_id: game_id,
      supervisor: context.supervisor
    }
  end
end
