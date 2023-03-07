defmodule Ships.Server.GameServer do
  @moduledoc false
  use GenServer

  alias Ships.Core.Game
  alias Ships.Server.GameRegistry
  alias Ships.Server.GameSupervisor

  @spec new_game() :: {:ok, any(), pid()}
  def new_game() do
    new_game(GameSupervisor)
  end

  @spec new_game(any()) :: {:ok, any(), pid()}
  def new_game(supervisor) do
    game_id = generate_id()
    {:ok, pid} = GameSupervisor.start_child(supervisor, game_id)
    {:ok, game_id, pid}
  end

  @spec join_game(any, any) :: :ok | :error
  def join_game(game_id, player_id) do
    GenServer.call(via_tuple(game_id), {:join_game, player_id})
  end

  @spec place_ship(any, any, {non_neg_integer(), non_neg_integer()}, atom()) :: {atom(), list()}
  def place_ship(game_id, player_id, coordinates, orientation) do
    GenServer.call(via_tuple(game_id), {:place_ship, player_id, coordinates, orientation})
  end

  @spec shoot(any, any, any) :: any
  def shoot(game_id, player_id, coordinates) do
    GenServer.call(via_tuple(game_id), {:shoot, player_id, coordinates})
  end

  @impl true
  @spec terminate(any, any) :: :error | :ok
  def terminate(supervisor, game_id) do
    pid = GameRegistry.whereis_name(game_id)

    case pid do
      :undefined -> :error
      _ -> GameSupervisor.terminate_child(supervisor, pid)
    end
  end

  def start_link(game_id: game_id) do
    GenServer.start_link(__MODULE__, [], name: via_tuple(game_id))
  end

  @impl true
  def init(_opts) do
    {:ok, state} = Game.new_game()
    {:ok, state}
  end

  @impl true
  def handle_call({:join_game, player_id}, _from, state) do
    {response, state} = Game.join_game(state, player_id)

    {:reply, response, state}
  end

  @impl true
  def handle_call({:place_ship, player_id, coordinates, orientation}, _from, state) do
    {response, state, ship_coord} = Game.place_ship(state, player_id, coordinates, orientation)

    {:reply, {response, ship_coord}, state}
  end

  @impl true
  def handle_call({:shoot, player_id, coordinates}, _from, state) do
    {response, state, shot_coordinates} = Game.shoot(state, player_id, coordinates)

    {:reply, {response, shot_coordinates}, state}
  end

  defp via_tuple(game_id) do
    {:via, GameRegistry, game_id}
  end

  defp generate_id do
    id =
      :crypto.strong_rand_bytes(10)
      |> Base.encode64()
      |> binary_part(0, 10)

    case GameRegistry.whereis_name(id) do
      :undefined -> id
      _ -> generate_id()
    end
  end
end
