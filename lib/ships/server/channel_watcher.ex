defmodule Ships.Server.ChannelWatcher do
  @moduledoc """
  The module watches over each game and if any player leaves the game,
  it ends the game and informs the other player.
  """

  use GenServer

  alias Ships.Server.GameServer

  def monitor(server_name, topic) do
    GenServer.call(server_name, {:monitor, topic})
  end

  def start_link(name) do
    GenServer.start_link(__MODULE__, [], name: name)
  end

  def init(_) do
    {:ok, %{}}
  end

  def handle_info(
        %Phoenix.Socket.Broadcast{topic: topic, event: "presence_diff", payload: payload},
        socket
      ) do
    game_id = String.replace(topic, "game:", "")
    leaves_size = map_size(payload.leaves)

    case leaves_size do
      0 ->
        :ok

      _ ->
        GameServer.terminate(game_id)

        ShipsWeb.Endpoint.broadcast(topic, "modal_msg", %{
          recipient: "both",
          message: "<h3>Your opponent has left.</h3>"
        })
    end

    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  def handle_call({:monitor, topic}, _from, state) do
    ShipsWeb.Endpoint.subscribe(topic)
    {:reply, :ok, state}
  end
end
