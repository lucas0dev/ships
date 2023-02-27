defmodule Ships.Core.Game do
  @moduledoc """
  Module is responsible for the mechanics of the game
  """
  defstruct player1: nil, player2: nil, status: :preparing, turn: :player1

  alias Ships.Core.Player

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
end
