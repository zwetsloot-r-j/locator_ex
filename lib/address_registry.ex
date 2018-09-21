defmodule Locator.AddressRegistry do
  @moduledoc """
  Module to define a registry of addresses.
  Addresses can only be registered at pre-compile time.
  Registered `Locator.Action`s can be obtained passing its adress into the locate function.

  ## Examples

      iex> defmodule Locator.AddressRegistry.ExampleAction do
      ...>   use Elixir.Locator.Action
      ...>
      ...>   def hi(), do: :lol
      ...> end
      ...>
      ...> defmodule Locator.AddressRegistry.ExampleAddressRegistry do
      ...>   use Elixir.Locator.AddressRegistry
      ...>
      ...>   action(:greet, Locator.AddressRegistry.ExampleAction)
      ...> end
      ...>
      ...> Locator.AddressRegistry.ExampleAddressRegistry.locate({:_, :greet})
      ...> |> Result.map(fn greeter -> greeter.hi() end)
      ...> |> Result.unwrap!()
      :lol

  """

  @typedoc """
  This type refers to the name of any module that uses `Locator.AddressRegistry`.
  """
  @type t :: module

  @typedoc """
  The options that can be passed into the use macro.
  - layers: a list of layers this module will be attached to.
  - settings: middleware and layer settings defined on a module using `Entangle.Seed`.
  """
  @type option ::
    {:settings, Entangle.Seed.t}
    | {:layers, Layers.layers | Layers.layer_query}
  @type options :: [option]

  @doc """
  Callback that will automatically be defined upon using `Locator.AddressRegistry`.
  The generated function is used by the `Locator` module this registry is registered to, and normally not called directly by the user.
  The action associated with the location passed as argument will be retrieved by calling this function.
  """
  @callback locate(Locator.location()) :: {:ok, Locator.Action.t()} | {:error, String.t()}

  @doc """
  Callback that will automatically be defined upon using `Locator.AddressRegistry`.
  Calling this function will obtain the layers this registry is associated with.
  """
  @callback active_layers() :: {:some, Layers.t()} | :none

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import Locator.AddressRegistry, only: :macros
      @behaviour Locator.AddressRegistry
      Module.register_attribute(__MODULE__, :actions, accumulate: true)
      Module.register_attribute(__MODULE__, :layers, [])

      @settings Keyword.get(opts, :settings)
                |> Option.return()
                |> Option.map(fn
                  settings when is_atom(settings) -> settings.settings()
                  settings -> settings
                end)
                |> Option.or_else(Entangle.Seed.default_settings())

      Keyword.get(opts, :layers)
      |> Option.return()
      |> Option.map(fn layers -> @layers layers end)

      @before_compile Locator.AddressRegistry
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    %Entangle.Seed{layers: layers, layer_mask: layer_mask} =
      Module.get_attribute(env.module, :settings)

    actions =
      Module.get_attribute(env.module, :actions)
      |> Enum.filter(fn {_, action, options} ->
        Keyword.get(options, :layers)
        |> Option.return()
        |> Option.or_else(action.active_layers())
        |> Option.flatten()
        |> Option.map(&Layers.enabled?(layers, layer_mask, &1))
        |> Option.or_else(true)
      end)
      |> Enum.map(fn {address, action, _} -> {address, action} end)
      |> Enum.into(%{})

    layers = Module.get_attribute(env.module, :layers)

    quote do
      @impl Locator.AddressRegistry
      def locate({domain, address}) do
        unquote(Macro.escape(actions))[address]
        |> Option.return()
        |> Option.map(&Result.return/1)
        |> Option.or_else(
          {:error, "No action found! " <> to_string(domain) <> ":" <> to_string(address)}
        )
      end

      @impl Locator.AddressRegistry
      def active_layers() do
        unquote(Macro.escape(layers))
        |> Option.return()
      end
    end
  end

  @doc """
  Macro to register an action to an address.
  You can pass the layers on which this action should be active as options, or define them on the module using `Locator.Action`.
  """
  defmacro action(address, action, options \\ []) do
    quote do
      @actions {unquote(address), unquote(action), unquote(options)}
    end
  end

  @doc """
  Macro to define the layers this registry will be associated with.
  Layers can be used to enable or disable this module based on the layer settings passed in as options on use.
  """
  defmacro layers(layers) do
    quote do
      @layers unquote(layers)
    end
  end
end
