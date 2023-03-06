defmodule ShipsWeb.GameChannelTest do
  use ShipsWeb.ChannelCase

  setup do
    {:ok, socket} = connect(ShipsWeb.UserSocket, %{}, %{})
    {:ok, _, socket} = subscribe_and_join(socket, "game:id", %{})

    %{socket: socket}
  end
end
