defmodule ShipsWeb.GameChannelTest do
  use ShipsWeb.ChannelCase

  setup do
    {:ok, socket} = connect(ShipsWeb.UserSocket, %{}, %{})
    {:ok, _, socket} = subscribe_and_join(socket, "game:id", %{})

    %{socket: socket}
  end

  describe "joining channel" do
    test "should generate and assign user_id string to socket", %{socket: socket} do
      user_id = socket.assigns.user_id

      assert String.length(user_id) > 0 == true
      assert String.valid?(user_id) == true
    end
  end
end
