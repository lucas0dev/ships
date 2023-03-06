defmodule ShipsWeb.GameChannel do
  @moduledoc """
  Module is responsible for interaction between the players and the game
  """

  use ShipsWeb, :channel

  @impl true
  def join("game:" <> _id, _payload, socket) do
    id = generate_id()
    socket = assign(socket, :user_id, id)
    {:ok, socket}
  end

  defp generate_id do
    :crypto.strong_rand_bytes(10)
    |> Base.encode64()
    |> binary_part(0, 10)
  end
end
