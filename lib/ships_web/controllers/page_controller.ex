defmodule ShipsWeb.PageController do
  use ShipsWeb, :controller

  def index(conn, _params) do
    board_range = 0..9
    render(conn, "index.html",
    row: board_range,
    col: board_range
  )
  end
end
