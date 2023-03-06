defmodule ShipsWeb.GameChannel do
  @moduledoc """
  Module is responsible for interaction between the players and the game
  """

  use ShipsWeb, :channel

  @impl true
  def join("game:" <> _id, _payload, socket) do
    {:ok, socket}
  end
end
