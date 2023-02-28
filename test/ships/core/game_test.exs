defmodule Ships.Core.GameTest do
  use ExUnit.Case

  alias Ships.Core.Game

  describe "new_game(player_id)" do
    test "should return %Game{} struct with player1 with player_id as id" do
      player_id = "player_one"
      game = Game.new_game(player_id)

      assert game.player1.id == player_id
    end
  end

  describe "join_game(game, player_id) when both players are nil" do
    test "should return %Game{} struct with player1 with player_id as id" do
      player_id = "player_one"
      game = %Game{}
      game = Game.join_game(game, player_id)

      assert game.player2 == nil
      assert game.player1.id == player_id
    end
  end

  describe "join_game(game, player_id) when there is already player1" do
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

  describe "join_game(game, player_id) when there are already 2 players" do
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

  describe "place_ship(player, coordinates, orientation) when params are valid" do
    test "should return {:preparing, player, ship_coordinates} with updated player ships" do
      game = Game.new_game("player1")
      player = game.player1
      coordinates = {0, 0}
      orientation = :horizontal

      {:preparing, updated_player, ship_coordinates} =
        Game.place_ship(player, coordinates, orientation)

      player_ship = Enum.at(updated_player.ships, 0)

      assert true = Enum.any?(ship_coordinates, fn value -> value == coordinates end)
      assert updated_player.ships != []
      assert ship_coordinates == player_ship
    end
  end

  describe "place_ship(player, coordinates, orientation) when coordinates were already used" do
    test "should return {:invalid_coordinates, player, []} with unchanged player" do
      game = Game.new_game("player1")
      player = game.player1
      coordinates = {0, 0}
      next_coordinates = {1, 0}
      orientation = :horizontal

      {:preparing, updated_player, _ship_coordinates} =
        Game.place_ship(player, coordinates, orientation)

      {response, player_after, coordinates_after} =
        Game.place_ship(updated_player, next_coordinates, orientation)

      assert coordinates_after == []
      assert response == :invalid_coordinates
      assert player_after == updated_player
    end
  end

  describe "place_ship(player, coordinates, orientation) with invalid coordinates" do
    test "should return {:invalid_coordinates, player, []} with unchanged player" do
      game = Game.new_game("player1")
      player = game.player1
      invalid_coordinates = {-1, 2}
      orientation = :horizontal

      {response, player_after, coordinates_after} =
        Game.place_ship(player, invalid_coordinates, orientation)

      assert coordinates_after == []
      assert response == :invalid_coordinates
      assert player_after == player
    end
  end

  describe "place_ship(player, coordinates, orientation) when not all ship coordinates belong to board" do
    test "should return {:invalid_coordinates, player, []} with unchanged player" do
      game = Game.new_game("player1")
      player = game.player1
      coordinates = {9, 9}
      orientation = :horizontal

      {response, player_after, coordinates_after} =
        Game.place_ship(player, coordinates, orientation)

      assert coordinates_after == []
      assert response == :invalid_coordinates
      assert player_after == player
    end
  end

  describe "place_ship(player, coordinates, orientation) when ship is too close to another" do
    test "should return {:invalid_coordinates, player, []} with unchanged player" do
      game = Game.new_game("player1")
      player = game.player1
      coordinates = {0, 0}
      next_coordinates = {1, 0}
      orientation = :vertical

      {:preparing, update_player, _coordinates_after} =
        Game.place_ship(player, coordinates, orientation)

      {response, player_after, coordinates_after} =
        Game.place_ship(update_player, next_coordinates, orientation)

      assert coordinates_after == []
      assert response == :invalid_coordinates
      assert player_after == update_player
    end
  end

  describe "place_ship(player, coordinates, orientation) when player already placed all of his ships" do
    test "should return {:all_placed, player, []} with unchanged player" do
      game = Game.new_game("player1")
      player = game.player1
      orientation = :horizontal

      {_response, player, _coordinates_after} = Game.place_ship(player, {0, 0}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {0, 2}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {0, 4}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {0, 6}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {0, 8}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {6, 0}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {6, 2}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {6, 4}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {6, 6}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {6, 8}, orientation)

      {response, player_after, _coordinates_after} = Game.place_ship(player, {8, 8}, orientation)

      assert player_after == player
      assert response == :all_placed
    end
  end

  describe "place_ship(player, coordinates, orientation) when player places his last ship" do
    test "should change his status to :ready" do
      game = Game.new_game("player1")
      player = game.player1
      orientation = :horizontal

      {_response, player, _coordinates_after} = Game.place_ship(player, {0, 0}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {0, 2}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {0, 4}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {0, 6}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {0, 8}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {6, 0}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {6, 2}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {6, 4}, orientation)
      {_response, player, _coordinates_after} = Game.place_ship(player, {6, 6}, orientation)
      {_response, player_after, _coordinates_after} = Game.place_ship(player, {6, 8}, orientation)

      assert player.status != player_after.status
      assert player_after.status == :ready
    end
  end
end
