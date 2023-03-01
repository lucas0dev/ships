defmodule Ships.Server.GameServerTest do
  use ExUnit.Case

  alias Ships.Core.Game
  alias Ships.Server.GameServer

  describe "start_link(game_id, player_id)" do
    test "should start a process with Game struct as a state" do
      player_id = "player1"
      {:ok, pid} = GameServer.start_link(game_id: :game_id, player_id: player_id)

      assert %Game{} = :sys.get_state(pid)
    end

    test "should assign player_id to game's player1 id" do
      player_id = "player1"
      {:ok, pid} = GameServer.start_link(game_id: :game_id, player_id: player_id)
      state = :sys.get_state(pid)
      state_player1_id = state.player1.id

      assert state_player1_id == player_id
    end
  end
end
