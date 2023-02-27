defmodule Ships.Core.GameTest do
  use ExUnit.Case

  alias Ships.Core.Game

  describe " new_game(player_id)" do
    test "should return %Game{} struct with player1 with player_id as id" do
      player_id = "player_one"
      game = Game.new_game(player_id)

      assert game.player1.id == player_id
    end
  end

  describe " join_game(game, player_id) when both players are nil" do
    test "should return %Game{} struct with player1 with player_id as id" do
      player_id = "player_one"
      game = %Game{}
      game = Game.join_game(game, player_id)

      assert game.player2 == nil
      assert game.player1.id == player_id
    end
  end

  describe " join_game(game, player_id) when there is already player1" do
    test "should return %Game{} struct with player2 with player_id as id" do
      player_one = "player_one"
      player_two = "player_two"

      game =
        Game.new_game(player_one)
        |> Game.join_game(player_two)

      assert game.player1.id == player_one
      assert game.player2.id == player_two
    end
  end

  describe " join_game(game, player_id) when there are already 2 players" do
    test "should return :error" do
      player_one = "player_one"
      player_two = "player_two"
      player_three = "player_three"

      result =
        Game.new_game(player_one)
        |> Game.join_game(player_two)
        |> Game.join_game(player_three)

      assert :error = result
    end
  end
end
