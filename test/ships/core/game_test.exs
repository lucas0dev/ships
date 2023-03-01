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
    setup [:place_all_ships]

    test "should return {:all_placed, game, []} with unchanged player", context do
      {response, reponse_game, _coordinates_after} =
        Game.place_ship(context.game_all_placed, context.player1, {8, 8}, :horizontal)

      assert reponse_game.player1 == context.game_all_placed.player1
      assert response == :all_placed
    end
  end

  describe "place_ship(game, player_id, coordinates, orientation) when player places his last ship" do
    setup [:place_all_ships]

    test "should change player's status to :ready", context do
      assert context.game.player1.status != context.game_all_placed.player1.status
      assert context.game_all_placed.player1.status == :ready
    end
  end

  describe "shoot(game, player_id, coordinates) when ship was hit" do
    setup [:place_one_ship]

    test "should return {:hit, game, coordinates}", context do
      {response, _game, _coordinates} =
        Game.shoot(context.game, context.player1, context.coordinates)

      assert response == :hit
    end

    test "should return list with shot at coordinates", context do
      {_response, _game, coordinates} =
        Game.shoot(context.game, context.player1, context.coordinates)

      assert coordinates == [context.coordinates]
    end

    test "should update opponent's got_hit_at list", context do
      {_response, game_after, _coordinates} =
        Game.shoot(context.game, context.player1, context.coordinates)

      opponent = game_after.player2

      assert opponent.got_hit_at == [{0, 0}]
    end

    test "should update shooter's shot_at list", context do
      {_response, game_after, _coordinates} =
        Game.shoot(context.game, context.player1, context.coordinates)

      shooter = game_after.player1

      assert shooter.shot_at == [{0, 0}]
    end

    test "should not change game turn to another player", context do
      {_response, game_after, _coordinates} =
        Game.shoot(context.game, context.player1, context.coordinates)

      assert game_after.turn == :player1
    end
  end

  describe "shoot(game, player_id, coordinates) when coordinate was already shot at" do
    setup [:place_one_ship]

    test "should return {:used, game, coordinates}", context do
      {_response, game, _coordinates} =
        Game.shoot(context.game, context.player1, context.coordinates)

      {response, _game, _coordinates} = Game.shoot(game, context.player1, context.coordinates)

      assert response == :used
    end

    test "should not change game turn to another player", context do
      {_response, game, _coordinates} =
        Game.shoot(context.game, context.player1, context.coordinates)

      {_response, game_after, _coordinates} =
        Game.shoot(game, context.player1, context.coordinates)

      assert game_after.turn == :player1
    end
  end

  describe "shoot(game, player_id, coordinates) when shot missed the ship" do
    setup [:place_one_ship]

    test "should return {:miss, game, coordinates}", context do
      {response, _game, _coordinates} = Game.shoot(context.game, context.player1, {8, 8})

      assert response == :miss
    end

    test "should update shooter's shot_at list", context do
      {_response, game_after, _coordinates} = Game.shoot(context.game, context.player1, {8, 8})
      shooter = game_after.player1

      assert shooter.shot_at == [{8, 8}]
    end

    test "should not update opponent's got_hit_at list", context do
      {_response, game_after, _coordinates} = Game.shoot(context.game, context.player1, {8, 8})
      opponent = game_after.player2

      assert opponent.got_hit_at == []
    end

    test "should change game turn to another player", context do
      {_response, game_player1, _coordinates} = Game.shoot(context.game, context.player1, {8, 8})
      {_response, game_player2, _coordinates} = Game.shoot(game_player1, context.player2, {8, 8})

      assert game_player1.turn == :player2
      assert game_player2.turn == :player1
    end
  end

  describe "shoot(game, player_id, coordinates) when ship was hit and destroyed" do
    setup [:place_one_ship, :shoot_three_times]

    test "should return {:destroyed, game, coordinates}", context do
      {response, _game_after, _coordinates} = Game.shoot(context.game, context.player1, {3, 0})

      assert response == :destroyed
    end

    test "should update shooter's shot_at list", context do
      {_response, game_after, _coordinates} = Game.shoot(context.game, context.player1, {3, 0})
      shooter = game_after.player1

      assert Enum.member?(shooter.shot_at, {3, 0}) == true
    end

    test "should update opponent's got_hit_at list", context do
      {_response, game_after, _coordinates} = Game.shoot(context.game, context.player1, {3, 0})
      opponent = game_after.player2

      assert Enum.member?(opponent.got_hit_at, {3, 0}) == true
    end

    test "should return a list with all the coordinates of the destroyed ship", context do
      {_response, _game_after, coordinates} = Game.shoot(context.game, context.player1, {3, 0})

      assert coordinates == [{0, 0}, {1, 0}, {2, 0}, {3, 0}]
    end

    test "should not change game turn to another player", context do
      {_response, game_after, _coordinates} = Game.shoot(context.game, context.player1, {3, 0})

      assert game_after.turn == :player1
    end
  end

  describe "shoot(game, player_id, coordinates) when all opponent ships have been destroyed" do
    setup [:place_all_ships, :destroy_all_ships]

    test "should return {:game_over, game, coordinates}", context do
      assert context.response == :game_over
    end
  end

  describe "shoot(game, player_id, coordinates) when its not player's turn" do
    setup [:place_all_ships]

    test "should return {:not_your_turn, game, coordinates}", context do
      {response, _game, _coordinates} =
        Game.shoot(context.game_all_placed, context.player2, {0, 0})

      assert response == :not_your_turn
    end

    test "should not change game turn to another player", context do
      {_response, game, _coordinates} =
        Game.shoot(context.game_all_placed, context.player2, {0, 0})

      assert game.turn == :player1
    end

    test "should not update shooter's shot_at list", context do
      {_response, game, _coordinates} =
        Game.shoot(context.game_all_placed, context.player2, {0, 0})

      shooter = game.player1

      assert shooter.shot_at == []
    end

    test "should not update opponent's got_hit_at list", context do
      {_response, game, _coordinates} =
        Game.shoot(context.game_all_placed, context.player2, {0, 0})

      opponent = game.player2

      assert opponent.got_hit_at == []
    end
  end

  defp destroy_all_ships(context) do
    {_response, game, _coordinates} = Game.shoot(context.game_all_placed, context.player1, {0, 0})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {1, 0})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {2, 0})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {3, 0})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {0, 2})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {1, 2})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {2, 2})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {0, 4})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {1, 4})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {2, 4})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {0, 6})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {1, 6})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {0, 8})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {1, 8})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {6, 0})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {7, 0})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {6, 2})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {6, 4})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {6, 6})
    {response, game, _coordinates} = Game.shoot(game, context.player1, {6, 8})

    %{game: game, response: response}
  end

  defp shoot_three_times(context) do
    {_response, game, _coordinates} = Game.shoot(context.game, context.player1, {0, 0})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {1, 0})
    {_response, game, _coordinates} = Game.shoot(game, context.player1, {2, 0})

    %{game: game}
  end

  defp place_one_ship(_context) do
    coordinates = {0, 0}
    player1 = "player1"
    player2 = "player2"
    game = Game.new_game(player1)
    game = Game.join_game(game, player2)

    {_response, game, _coordinates_after} =
      Game.place_ship(game, player2, coordinates, :horizontal)

    {_response, _game, _coordinates_after} =
      Game.place_ship(game, player1, coordinates, :horizontal)

    %{game: game, player1: player1, player2: player2, coordinates: coordinates}
  end

  defp place_all_ships(_context) do
    player1 = "player1"
    player2 = "player2"
    game = Game.new_game(player1)
    game = Game.join_game(game, player2)
    orientation = :horizontal

    {_response, game, _coordinates_after} = Game.place_ship(game, player2, {0, 0}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player2, {0, 2}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player2, {0, 4}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player2, {0, 6}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player2, {0, 8}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player2, {6, 0}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player2, {6, 2}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player2, {6, 4}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player2, {6, 6}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player2, {6, 8}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player1, {0, 0}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player1, {0, 2}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player1, {0, 4}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player1, {0, 6}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player1, {0, 8}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player1, {6, 0}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player1, {6, 2}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player1, {6, 4}, orientation)
    {_response, game, _coordinates_after} = Game.place_ship(game, player1, {6, 6}, orientation)

    {_response, game_all_placed, _coordinates_after} =
      Game.place_ship(game, player1, {6, 8}, orientation)

    %{game: game, game_all_placed: game_all_placed, player1: player1, player2: player2}
  end
end
