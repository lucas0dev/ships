defmodule Ships.Core.Game do
  @moduledoc """
  Module is responsible for the mechanics of the game
  """
  defstruct player1: nil, player2: nil, status: :preparing, turn: :player1

  alias Ships.Core.Player
  alias Ships.Core.Ship

  @board_border 9

  @spec new_game(any()) :: %__MODULE__{}
  def new_game(player_id) do
    join_game(%__MODULE__{}, player_id)
  end

  @spec join_game(%__MODULE__{}, any()) :: %__MODULE__{} | :error
  def join_game(
        %__MODULE__{player1: _, player2: _, status: :preparing, turn: _} = game,
        player_id
      ) do
    player = %Player{id: player_id}

    cond do
      game.player1 == nil -> %{game | player1: player}
      game.player2 == nil -> %{game | player2: player}
      true -> :error
    end
  end

  @spec place_ship(Player.t(), {non_neg_integer(), non_neg_integer()}, atom()) ::
          {atom(), Player.t(), list}
  def place_ship(%Player{} = player, coordinates, orientation) do
    with {:ok, size} <- next_ship_size(player),
         :ok <- check_coordinates(coordinates, size, orientation),
         {:ok, ship} <- Ship.new(coordinates, size, orientation),
         {:ok, player} <- add_ship(player, ship) do
      {player.status, player, ship.coordinates}
    else
      :all_placed -> {:all_placed, player, []}
      _ -> {:invalid_coordinates, player, []}
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

  defp check_coordinates({x, y}, size, orientation) when x >= 0 and y >= 0 do
    not_in_border =
      case orientation do
        :horizontal -> x + size - 1 > @board_border
        :vertical -> y + size - 1 > @board_border
      end

    if not_in_border do
      :invalid
    else
      :ok
    end
  end

  defp check_coordinates(_, _, _) do
    :invalid
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
