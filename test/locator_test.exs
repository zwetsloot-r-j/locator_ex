defmodule LocatorTest do
  use ExUnit.Case
  doctest Locator

  test "setup a locator" do
    defmodule LoggerTest do
      use Entangle.Thorn, layers: {:!, :prod}

      def run(next) do
        fn state ->
          state
          |> IO.inspect(label: IO.ANSI.blue <> "input" <> IO.ANSI.reset)
          |> next.()
          |> IO.inspect(label: IO.ANSI.cyan <> "response" <> IO.ANSI.reset)
        end
      end
    end

    defmodule SettingsTest do
      use Entangle.Seed

      layers([:prod, :dev, :test])
      active_layers([Mix.env()])

      root(LoggerTest)
    end

    defmodule UpdateTest do
      use Locator.Action, settings: SettingsTest

      def update({player, name}), do: {:ok, %{player | name: name}}

      entangle(:run, [
        branch(&__MODULE__.update/1)
      ])
    end

    defmodule DomainTest.Player do
      use Locator.AddressRegistry, settings: SettingsTest

      action(:update, UpdateTest)
    end

    defmodule LocatorTest do
      use Locator, settings: SettingsTest

      domain(:player, DomainTest.Player)
    end

    LocatorTest.locate({:player, :update})
    |> Result.bind(fn action -> action.run({%{name: "Meep"}, "Sheep"}) end)
    |> Kernel.==({:ok, %{name: "Sheep"}})
    |> assert()

    LocatorTest.locate({:player, :new})
    |> Result.bind(fn action -> action.run(1) end)
    |> Kernel.==({:error, "No action found! player:new"})
    |> assert()

    LocatorTest.locate({:items, :find})
    |> Result.bind(fn action -> action.run(1) end)
    |> Kernel.==({:error, "Domain not found! items:find"})
    |> assert()
  end
end
