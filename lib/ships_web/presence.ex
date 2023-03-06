defmodule ShipsWeb.Presence do
  @moduledoc false
  use Phoenix.Presence,
    otp_app: :ships,
    pubsub_server: Ships.PubSub
end
