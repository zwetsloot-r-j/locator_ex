defmodule Locator.Action do
  @moduledoc """
  The action that can be assigned to a location.
  The implementation of the action is free to the user, as long as it implements the `Locator.Action` behaviour.
  If importing `Locator.Action` with use, the necessary behaviour will be implemented automatically,
  and function compositions can be made with the `Entangle.Entangler.entangle` macro.
  """

  @typedoc """
  Type referring to a `Locator.Action`.
  """
  @type t :: module

  @typedoc """
  Definition of options that can be passed to the use macro.
  """
  @type option :: {:settings, Entangle.Seed.t}
    | {:layers, Layers.layers | Layers.layer_query}
  @type options :: [option]

  @doc """
  Obtained the layers this action is associated with.
  """
  @callback active_layers() :: {:some, Layers.t} | :none

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      import Locator.Action, only: :macros
      @behaviour Locator.Action

      settings = Keyword.get(opts, :settings)
      |> Option.return()
      |> Option.or_else(Keyword.get(opts, :seed))
      |> Option.return()
      |> Option.or_else(Entangle.Seed.default_settings())

      use Entangle.Entangler, seed: settings

      Module.register_attribute(__MODULE__, :layers, [])

      Keyword.get(opts, :layers)
      |> Option.return()
      |> Option.map(fn layers -> @layers layers end)

      @before_compile Locator.Action
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    layers = Module.get_attribute(env.module, :layers)

    quote do
      @impl Locator.Action
      def active_layers() do
        unquote(Macro.escape(layers))
        |> Option.return()
      end
    end
  end

  @doc """
  Macro to define the layers this module will be associated with.
  """
  @spec layers(Layers.layers) :: Macro.t
  defmacro layers(layers) do
    quote do
      @layers unquote(layers)
    end
  end
end
