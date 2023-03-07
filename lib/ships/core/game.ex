defmodule Ships.Core.Game do
  @moduledoc """
  Module is responsible for the mechanics of the game
  """
  defstruct player1: nil, player2: nil, status: :preparing, turn: :player1

  alias Ships.Core.Player
  alias Ships.Core.Ship

  @available_ships [4, 3, 3, 2, 2, 2, 1, 1, 1, 1]
  @board_border 9

  @spec new_game() :: {:ok, %__MODULE__{}}
  def new_game() do
    {:ok, %__MODULE__{}}
  end

  @spec join_game(%__MODULE__{}, any()) :: {:ok, %__MODULE__{}} | {:error, %__MODULE__{}}
  def join_game(
        %__MODULE__{player1: _, player2: _, status: :preparing, turn: _} = game,
        player_id
      ) do
    player = %Player{id: player_id}

    cond do
      game.player1 == nil -> {:ok, %{game | player1: player}}
      game.player2 == nil -> {:ok, %{game | player2: player}}
      true -> {:game_full, game}
    end
  end

  @spec place_ship(%__MODULE__{}, any(), {non_neg_integer(), non_neg_integer()}, atom()) ::
          {atom(), %__MODULE__{}, list}
  def place_ship(%__MODULE__{} = game, player_id, coordinates, orientation) do
    {player_num, player} = get_player(game, player_id)

    {response, updated_player, ship_coordinates} =
      with {:ok, size} <- next_ship_size(player),
           true <- in_board_range?(coordinates, size, orientation),
           {:ok, ship} <- Ship.new(coordinates, size, orientation),
           {:ok, player} <- add_ship(player, ship) do
        {player.status, player, ship.coordinates}
      else
        :all_placed -> {:all_placed, player, []}
        _ -> {:invalid_coordinates, player, []}
      end

    game = Map.replace(game, player_num, updated_player)

    {response, game, ship_coordinates}
  end

  @spec shoot(%__MODULE__{}, any(), {non_neg_integer(), non_neg_integer()}) ::
          {atom(), %__MODULE__{}, list}
  def shoot(%__MODULE__{} = game, player_id, coordinates) do
    {shooter, opponent} = assign_roles(game, player_id)

    {response, updated_shooter, updated_opponent, response_coordinates} =
      with :allowed <- is_player_allowed(game, player_id),
           false <- already_used?(shooter, coordinates),
           {:hit, updated_shooter, updated_opponent} <-
             take_a_shot(shooter, opponent, coordinates),
           {ship_status, ship_coordinates} <- check_if_destroyed(updated_opponent, coordinates),
           :not_yet <- all_ships_destroyed(updated_opponent) do
        {ship_status, updated_shooter, updated_opponent, ship_coordinates}
      else
        :not_allowed -> {:not_your_turn, shooter, opponent, [coordinates]}
        true -> {:used, shooter, opponent, [coordinates]}
        {:miss, updated_shooter} -> {:miss, updated_shooter, opponent, [coordinates]}
        :all_destroyed -> {:game_over, shooter, opponent, [coordinates]}
      end

    game =
      update_game(game, updated_shooter, updated_opponent)
      |> assign_next_turn(response)

    {response, game, response_coordinates}
  end

  defp is_player_allowed(game, player_id) do
    allowed_player = game.turn

    shooter =
      cond do
        game.player1.id == player_id -> :player1
        game.player2.id == player_id -> :player2
      end

    case shooter == allowed_player do
      true -> :allowed
      false -> :not_allowed
    end
  end

  defp update_game(game, shooter, opponent) do
    case shooter.id == game.player1.id do
      true -> %{game | player1: shooter, player2: opponent}
      false -> %{game | player2: shooter, player1: opponent}
    end
  end

  defp all_ships_destroyed(opponent) do
    case length(opponent.got_hit_at) == Enum.sum(@available_ships) do
      true -> :all_destroyed
      false -> :not_yet
    end
  end

  defp check_if_destroyed(player, coordinates) do
    player_ships = Map.get(player, :ships)
    ship_coordinates = Enum.find(player_ships, fn ship -> Enum.member?(ship, coordinates) end)
    hit_coordinates = Map.get(player, :got_hit_at)

    result =
      Enum.all?(ship_coordinates, fn coordinate -> Enum.member?(hit_coordinates, coordinate) end)

    case result do
      true -> {:destroyed, ship_coordinates}
      _ -> {:hit, [coordinates]}
    end
  end

  defp take_a_shot(shooter, opponent, coordinates) do
    opponent_ships = Map.get(opponent, :ships)
    updated_shooter = update_shot_coordinates(shooter, coordinates)
    shot_result = check_if_hit(opponent_ships, coordinates)

    case shot_result do
      true ->
        updated_opponent = update_hit_at(opponent, coordinates)
        {:hit, updated_shooter, updated_opponent}

      _ ->
        {:miss, updated_shooter}
    end
  end

  defp update_shot_coordinates(player, coordinates) do
    Map.update!(player, :shot_at, fn shot_at -> [coordinates | shot_at] end)
  end

  defp update_hit_at(player, coordinates) do
    Map.update!(player, :got_hit_at, fn hit_coordinates ->
      [coordinates | hit_coordinates]
    end)
  end

  defp check_if_hit(ships_coordinates, shot_coordinates) do
    Enum.any?(ships_coordinates, fn coordinates ->
      Enum.member?(coordinates, shot_coordinates)
    end)
  end

  defp already_used?(shooter, coordinates) do
    Enum.member?(shooter.shot_at, coordinates)
  end

  defp assign_next_turn(game, shot_response) do
    turn =
      case shot_response do
        :hit -> game.turn
        :miss -> change_turn(game.turn)
        :used -> game.turn
        :destroyed -> game.turn
        :game_over -> game.turn
        :not_your_turn -> game.turn
      end

    %{game | turn: turn}
  end

  defp change_turn(turn) do
    case turn do
      :player1 -> :player2
      :player2 -> :player1
    end
  end

  defp assign_roles(%__MODULE__{} = game, player_id) do
    {shooter, opponent} =
      cond do
        player_id == game.player1.id -> {game.player1, game.player2}
        player_id == game.player2.id -> {game.player2, game.player1}
      end

    {shooter, opponent}
  end

  defp get_player(%__MODULE__{} = game, player_id) do
    cond do
      game.player1.id == player_id -> {:player1, game.player1}
      game.player2.id == player_id -> {:player2, game.player2}
    end
  end

  defp add_ship(%Player{} = player, %Ship{} = ship) do
    with true <- coordinates_available?(player, ship.coordinates),
         true <- surroundings_empty?(player, ship.coordinates, ship.direction),
         player <-
           Map.update!(player, :ships, fn already_placed ->
             [ship.coordinates | already_placed]
           end) do
      {:ok, maybe_update_status(player)}
    else
      _ -> :error
    end
  end

  defp coordinates_available?(player, coordinates) do
    players_ships = List.flatten(Map.get(player, :ships))
    !Enum.any?(coordinates, fn coordinate -> Enum.member?(players_ships, coordinate) end)
  end

  defp surroundings_empty?(player, coordinates, direction) do
    players_ships = List.flatten(Map.get(player, :ships))
    neighbour_cells = neighbours_for(coordinates, direction)
    !Enum.any?(neighbour_cells, fn coordinate -> Enum.member?(players_ships, coordinate) end)
  end

  defp maybe_update_status(player) do
    case length(player.available_ships) - length(player.ships) do
      x when x == 0 -> Map.replace(player, :status, :ready)
      _ -> player
    end
  end

  defp next_ship_size(player) do
    size = Enum.at(player.available_ships, length(player.ships))

    case length(player.available_ships) - length(player.ships) do
      x when x >= 1 -> {:ok, size}
      _ -> :all_placed
    end
  end

  defp in_board_range?({x, y}, size, orientation) when x >= 0 and y >= 0 do
    case orientation do
      :horizontal -> x + size - 1 <= @board_border
      :vertical -> y + size - 1 <= @board_border
    end
  end

  defp in_board_range?(_, _, _) do
    false
  end

  defp neighbours_for(coordinates, direction) do
    {first_x, first_y} = Enum.at(coordinates, 0)
    coordinates_size = length(coordinates)

    case direction do
      :horizontal ->
        upper = for i <- -1..coordinates_size, do: {first_x + i, first_y + 1}
        middle = for i <- -1..coordinates_size, do: {first_x + i, first_y}
        bottom = for i <- -1..coordinates_size, do: {first_x + i, first_y - 1}
        (upper ++ middle ++ bottom) -- coordinates

      :vertical ->
        left = for i <- -1..coordinates_size, do: {first_x - 1, first_y + i}
        middle = for i <- -1..coordinates_size, do: {first_x, first_y + i}
        right = for i <- -1..coordinates_size, do: {first_x + 1, first_y + i}
        (left ++ middle ++ right) -- coordinates
    end
  end
end
