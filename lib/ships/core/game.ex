defmodule Ships.Core.Game do
  @moduledoc """
  Module is responsible for the mechanics of the game
  """
  defstruct player1: nil, player2: nil, status: :preparing, turn: :player1

  alias Ships.Core.Player
  alias Ships.Core.Ship

  @board_border 9

  @spec new_game() :: {:ok, %__MODULE__{}}
  def new_game() do
    {:ok, %__MODULE__{}}
  end

  @spec join_game(%__MODULE__{}, any()) :: {:ok, %__MODULE__{}} | {:error, %__MODULE__{}}
  def join_game(%__MODULE__{status: :preparing} = game, player_id) do
    player = %Player{id: player_id}

    cond do
      game.player1 == nil -> {:ok, %{game | player1: player}}
      game.player2 == nil -> {:ok, %{game | player2: player}}
      true -> {:game_full, game}
    end
  end

  @spec get_next_ship(%__MODULE__{}, any()) ::
          {:ok, non_neg_integer()} | {:all_placed, nil} | {:last_ship, non_neg_integer()}
  def get_next_ship(%__MODULE__{} = game, player_num) do
    player = Map.get(game, player_num)
    ship_size = Enum.at(player.available_ships, length(player.ships))

    case length(player.available_ships) - length(player.ships) do
      x when x == 0 -> {:all_placed, nil}
      x when x >= 1 -> {:ok, ship_size}
    end
  end

  @spec place_ship(%__MODULE__{}, any(), {non_neg_integer(), non_neg_integer()}, atom()) ::
          {:ok | :last_placed | :all_placed | :invalid_coordinates, %__MODULE__{}, list}
  def place_ship(%__MODULE__{} = game, player_num, coordinates, orientation) do
    player = Map.get(game, player_num)

    {response, updated_player, coordinates_list} =
      with {response, size} <- next_ship_size(player),
           true <- in_board_range?(coordinates, size, orientation),
           {:ok, ship} <- Ship.new(coordinates, size, orientation),
           {:ok, player} <- add_ship(player, ship),
           player <- update_status(player, response) do
        {response, player, ship.coordinates}
      else
        :all_placed -> {:all_placed, player, []}
        _ -> {:invalid_coordinates, player, []}
      end

    game = Map.replace(game, player_num, updated_player)
    game = update_game_status(game)

    {response, game, coordinates_list}
  end

  @spec shoot(%__MODULE__{}, any(), {non_neg_integer(), non_neg_integer()}) ::
          {atom(), %__MODULE__{}, list}
  def shoot(%__MODULE__{} = game, player_num, coordinates) do
    {shooter, opponent} = assign_roles(game, player_num)

    {response, updated_shooter, updated_opponent, coordinates_list} =
      with :allowed <- is_player_allowed(game, player_num),
           false <- coordinates_used?(shooter, coordinates),
           {:hit, updated_shooter, updated_opponent} <-
             take_a_shot(shooter, opponent, coordinates),
           {shot_result, coordinates_list} <- check_if_destroyed(updated_opponent, coordinates),
           :not_yet <- all_ships_destroyed(updated_opponent) do
        {shot_result, updated_shooter, updated_opponent, coordinates_list}
      else
        :not_allowed -> {:not_your_turn, shooter, opponent, []}
        true -> {:used, shooter, opponent, []}
        {:miss, updated_shooter} -> {:miss, updated_shooter, opponent, []}
        :all_destroyed -> {:game_over, shooter, opponent, []}
      end

    game =
      update_game(game, updated_shooter, updated_opponent)
      |> assign_next_turn(response)

    {response, game, coordinates_list}
  end

  @spec status(%__MODULE__{}) :: :preparing | :in_progress | :game_over
  def status(%__MODULE__{} = game) do
    game.status
  end

  @spec update_game_status(%__MODULE__{}) :: %__MODULE__{}
  defp update_game_status(game) do
    case check_players(game) do
      :ready -> Map.replace(game, :status, :in_progress)
      :not_ready -> game
    end
  end

  @spec check_players(%__MODULE__{}) :: :ready | :not_ready
  defp check_players(game) do
    with :ready <- get_status(game.player1),
         :ready <- get_status(game.player2) do
      :ready
    else
      _ -> :not_ready
    end
  end

  @spec update_status(Player.t(), atom) :: Player.t()
  defp update_status(player, status) do
    if status == :last_placed do
      Map.update!(player, :status, fn _ -> :ready end)
    else
      player
    end
  end

  @spec get_status(Player.t()) :: atom | nil
  defp get_status(player) do
    if player, do: player.status, else: nil
  end

  @spec is_player_allowed(%__MODULE__{}, atom) :: :allowed | :not_allowed
  defp is_player_allowed(game, player_num) do
    allowed_player = game.turn

    case player_num == allowed_player do
      true -> :allowed
      false -> :not_allowed
    end
  end

  @spec update_game(%__MODULE__{}, Player.t(), Player.t()) :: %__MODULE__{}
  defp update_game(game, shooter, opponent) do
    case shooter.id == game.player1.id do
      true -> %{game | player1: shooter, player2: opponent}
      false -> %{game | player2: shooter, player1: opponent}
    end
  end

  @spec all_ships_destroyed(Player.t()) :: :all_destroyed | :not_yet
  defp all_ships_destroyed(opponent) do
    case length(opponent.got_hit_at) == Enum.sum(opponent.available_ships) do
      true -> :all_destroyed
      false -> :not_yet
    end
  end

  @spec check_if_destroyed(Player.t(), tuple()) :: {atom, list}
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

  @spec take_a_shot(Player.t(), Player.t(), tuple) ::
          {:hit, Player.t(), Player.t()} | {:miss, Player.t()}
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

  @spec update_shot_coordinates(Player.t(), tuple) :: Player.t()
  defp update_shot_coordinates(player, coordinates) do
    Map.update!(player, :shot_at, fn shot_at -> [coordinates | shot_at] end)
  end

  @spec update_hit_at(Player.t(), tuple) :: Player.t()
  defp update_hit_at(player, coordinates) do
    Map.update!(player, :got_hit_at, fn hit_coordinates ->
      [coordinates | hit_coordinates]
    end)
  end

  @spec check_if_hit(list, tuple) :: boolean()
  defp check_if_hit(ships_coordinates, shot_coordinates) do
    Enum.any?(ships_coordinates, fn coordinates ->
      Enum.member?(coordinates, shot_coordinates)
    end)
  end

  @spec coordinates_used?(Player.t(), tuple) :: boolean()
  defp coordinates_used?(shooter, coordinates) do
    Enum.member?(shooter.shot_at, coordinates)
  end

  @spec assign_next_turn(%__MODULE__{}, atom) :: %__MODULE__{}
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

  @spec change_turn(atom) :: :player1 | :player2
  defp change_turn(turn) do
    case turn do
      :player1 -> :player2
      :player2 -> :player1
    end
  end

  @spec assign_roles(%__MODULE__{}, atom) :: {Player.t(), Player.t()}
  defp assign_roles(%__MODULE__{} = game, player_num) do
    {shooter, opponent} =
      cond do
        player_num == :player1 -> {game.player1, game.player2}
        player_num == :player2 -> {game.player2, game.player1}
      end

    {shooter, opponent}
  end

  @spec add_ship(Player.t(), Ship.t()) :: {:ok, Player.t()} | :error
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

  @spec coordinates_available?(Player.t(), list) :: boolean
  defp coordinates_available?(player, coordinates_list) do
    players_ships = List.flatten(Map.get(player, :ships))
    !Enum.any?(coordinates_list, fn coordinates -> Enum.member?(players_ships, coordinates) end)
  end

  @spec surroundings_empty?(Player.t(), list, atom) :: boolean
  defp surroundings_empty?(player, coordinates_list, direction) do
    players_ships = List.flatten(Map.get(player, :ships))
    neighbour_cells = neighbours_for(coordinates_list, direction)
    !Enum.any?(neighbour_cells, fn coordinates -> Enum.member?(players_ships, coordinates) end)
  end

  @spec maybe_update_status(Player.t()) :: Player.t()
  defp maybe_update_status(player) do
    case length(player.available_ships) - length(player.ships) do
      x when x == 0 -> Map.replace(player, :status, :ready)
      _ -> player
    end
  end

  @spec next_ship_size(Player.t()) :: {:ok, integer} | {:last_placed, integer} | :all_placed
  defp next_ship_size(player) do
    size = Enum.at(player.available_ships, length(player.ships))

    case length(player.available_ships) - length(player.ships) do
      x when x > 1 -> {:ok, size}
      x when x == 1 -> {:last_placed, size}
      _ -> :all_placed
    end
  end

  @spec in_board_range?(tuple, integer, atom) :: boolean
  defp in_board_range?({x, y}, size, orientation) when x >= 0 and y >= 0 do
    case orientation do
      :horizontal -> x + size - 1 <= @board_border
      :vertical -> y + size - 1 <= @board_border
    end
  end

  defp in_board_range?(_, _, _) do
    false
  end

  @spec neighbours_for(list, atom) :: list
  defp neighbours_for(coordinates_list, direction) do
    {first_x, first_y} = Enum.at(coordinates_list, 0)
    coordinates_size = length(coordinates_list)

    case direction do
      :horizontal ->
        upper = for i <- -1..coordinates_size, do: {first_x + i, first_y + 1}
        middle = for i <- -1..coordinates_size, do: {first_x + i, first_y}
        bottom = for i <- -1..coordinates_size, do: {first_x + i, first_y - 1}
        (upper ++ middle ++ bottom) -- coordinates_list

      :vertical ->
        left = for i <- -1..coordinates_size, do: {first_x - 1, first_y + i}
        middle = for i <- -1..coordinates_size, do: {first_x, first_y + i}
        right = for i <- -1..coordinates_size, do: {first_x + 1, first_y + i}
        (left ++ middle ++ right) -- coordinates_list
    end
  end
end
