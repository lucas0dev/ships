defmodule Ships.Core.ShipTest do
  use ExUnit.Case

  alias Ships.Core.Ship

  describe "new({x, y}, size, direction)" do
    test "should return {:ok, %Ship{}} when params are valid" do
      coordinates = {1, 1}
      size = 2
      direction = :horizontal
      result = Ship.new(coordinates, size, direction)

      assert {:ok, %Ship{}} = result
    end

    test "should return :error if on of params is invalid" do
      coordinates = {1, 1}
      size = 2
      direction = :horizontal

      assert :error = Ship.new({"asd", 3}, size, direction)
      assert :error = Ship.new(coordinates, "size", direction)
      assert :error = Ship.new(coordinates, size, "direction")
    end
  end
end
