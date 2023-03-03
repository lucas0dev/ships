defmodule ShipsWeb.LobbyChannelTest do
  use ShipsWeb.ChannelCase

  setup do
    {:ok, socket} = connect(ShipsWeb.UserSocket, %{}, %{})
    {:ok, _, socket} = subscribe_and_join(socket, "lobby", %{})

    %{socket: socket}
  end

  test "join_game replies with status ok", %{socket: socket} do
    ref = push(socket, "join_game", %{})
    assert_reply ref, :ok
  end
end
