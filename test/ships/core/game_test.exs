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

  describe "place_ship(game, player_id, coordinates, orientation) when params are valid" do
    test "should return {:preparing, game, ship_coordinates} with updated player ships" do
      player_id = "player1"
      game = Game.new_game(player_id)
      coordinates = {0, 0}
      orientation = :horizontal

      {:preparing, updated_game, ship_coordinates} =
        Game.place_ship(game, player_id, coordinates, orientation)

      player_ship = Enum.at(updated_game.player1.ships, 0)

      assert true = Enum.any?(ship_coordinates, fn value -> value == coordinates end)
      assert updated_game.player1.ships != []
      assert ship_coordinates == player_ship
    end
  end

  describe "place_ship(game, player_id, coordinates, orientation) when coordinates were already used" do
    test "should return {:invalid_coordinates, game, []} with unchanged player" do
      player_id = "player1"
      game = Game.new_game(player_id)
      coordinates = {0, 0}
      next_coordinates = {1, 0}
      orientation = :horizontal

      {:preparing, updated_game, _ship_coordinates} =
        Game.place_ship(game, player_id, coordinates, orientation)

      {response, game_after, coordinates_after} =
        Game.place_ship(updated_game, player_id, next_coordinates, orientation)

      assert coordinates_after == []
      assert response == :invalid_coordinates
      assert updated_game.player1 == game_after.player1
    end
  end

  describe "place_ship(game, player_id, coordinates, orientation) with invalid coordinates" do
    test "should return {:invalid_coordinates, game, []} with unchanged player" do
      player_id = "player1"
      game = Game.new_game(player_id)
      invalid_coordinates = {-1, 2}
      orientation = :horizontal

      {response, game_after, coordinates_after} =
        Game.place_ship(game, player_id, invalid_coordinates, orientation)

      assert coordinates_after == []
      assert response == :invalid_coordinates
      assert game_after.player1 == game.player1
    end
  end

  describe "place_ship(game, player_id, coordinates, orientation) when not all ship coordinates belong to board" do
    test "should return {:invalid_coordinates, game, []} with unchanged player" do
      player_id = "player1"
      game = Game.new_game(player_id)
      coordinates = {9, 9}
      orientation = :horizontal

      {response, game_after, coordinates_after} =
        Game.place_ship(game, player_id, coordinates, orientation)

      assert coordinates_after == []
      assert response == :invalid_coordinates
      assert game_after.player1 == game.player1
    end
  end

  describe "place_ship(game, player_id, coordinates, orientation) when ship is too close to another" do
    test "should return {:invalid_coordinates, game, []} with unchanged player" do
      player_id = "player1"
      game = Game.new_game(player_id)
      coordinates = {0, 0}
      next_coordinates = {1, 0}
      orientation = :vertical

      {:preparing, updated_game, _coordinates_after} =
        Game.place_ship(game, player_id, coordinates, orientation)

      {response, game_after, coordinates_after} =
        Game.place_ship(updated_game, player_id, next_coordinates, orientation)

      assert coordinates_after == []
      assert response == :invalid_coordinates
      assert game_after.player1 == updated_game.player1
    end
  end

  describe "place_ship(game, player_id, coordinates, orientation) when player already placed all of his ships" do
    test "should return {:all_placed, game, []} with unchanged player" do
      player_id = "player1"
      game = Game.new_game(player_id)
      orientation = :horizontal

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {0, 0}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {0, 2}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {0, 4}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {0, 6}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {0, 8}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {6, 0}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {6, 2}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {6, 4}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {6, 6}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {6, 8}, orientation)

      {response, game_after, _coordinates_after} =
        Game.place_ship(game, player_id, {8, 8}, orientation)

      assert game_after.player1 == game.player1
      assert response == :all_placed
    end
  end

  describe "place_ship(game, player_id, coordinates, orientation) when player places his last ship" do
    test "should change player's status to :ready" do
      player_id = "player1"
      game = Game.new_game(player_id)
      orientation = :horizontal

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {0, 0}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {0, 2}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {0, 4}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {0, 6}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {0, 8}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {6, 0}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {6, 2}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {6, 4}, orientation)

      {_response, game, _coordinates_after} =
        Game.place_ship(game, player_id, {6, 6}, orientation)

      {_response, game_after, _coordinates_after} =
        Game.place_ship(game, player_id, {6, 8}, orientation)

      assert game.player1.status != game_after.player1.status
      assert game_after.player1.status == :ready
    end
  end
end
