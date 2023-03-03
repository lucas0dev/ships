defmodule ShipsWeb.LobbyChannel do
  @moduledoc """
  Channel is responsible for finding and joining a game with only 1 player.
  """
  use ShipsWeb, :channel

  @impl true
  def join("lobby", _payload, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_in("join_game", _payload, socket) do
    {:reply, :ok, socket}
  end
end
