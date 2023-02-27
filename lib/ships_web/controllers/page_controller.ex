defmodule ShipsWeb.PageController do
  use ShipsWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
