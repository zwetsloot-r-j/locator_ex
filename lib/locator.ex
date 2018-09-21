defmodule Locator do
  @moduledoc """
  `Locator` is a module to manage application flow by registering actions containing logic to locations defined by 'domain' and 'address'.
  A locator contains one or more 'domains', which themselves consist of multiple actions registered by 'address'. 
  This allows for an application to be structured with clear separation of concerns, while still being able to easily re-use generic actions. At the same time, it makes it very easy to swap in and out functionality without changing the interface of the application, and one could even flag actions or domains with layers to automatically enable or disable them based on the environment of config.

  ## Examples

      iex> defmodule Locator.Example.Debugger do
      ...>   use Entangle.Thorn, layers: {:!, :prod} # any environment but production
      ...>
      ...>   def run(next) do
      ...>     fn state ->
      ...>       state
      ...>       |> IO.inspect(label: IO.ANSI.blue <> "input" <> IO.ANSI.reset)
      ...>       |> next.()
      ...>       |> IO.inspect(label: IO.ANSI.cyan <> "response" <> IO.ANSI.reset)
      ...>     end
      ...>   end
      ...> end
      ...>
      ...> defmodule Locator.Example.Settings do
      ...>   use Entangle.Seed
      ...>
      ...>   layers([:prod, :dev, :test])
      ...>   active_layers([Mix.env()])
      ...>   root(Locator.Example.Debugger)
      ...> end
      ...>
      ...> defmodule Locator.Example.User.New do
      ...>   use Elixir.Locator.Action, settings: LocatorTest.Locator.Example.Settings
      ...>
      ...>   def new(name), do: {:ok, %{id: 1, name: name}}
      ...>
      ...>   entangle(:run, [
      ...>     branch(&__MODULE__.new/1)
      ...>   ])
      ...> end
      ...>
      ...> defmodule Locator.Example.Domain.User do
      ...>   use Elixir.Locator.AddressRegistry, settings: LocatorTest.Locator.Example.Settings
      ...>
      ...>   action(:new, LocatorTest.Locator.Example.User.New)
      ...> end
      ...>
      ...> defmodule Locator.Example do
      ...>   use Elixir.Locator, settings: LocatorTest.Locator.Example.Settings
      ...>
      ...>   domain(:user, LocatorTest.Locator.Example.Domain.User)
      ...> end
      ...>
      ...> Locator.Example.locate({:user, :new})
      ...> |> Result.bind(&(&1.run("Lionel")))
      {:ok, %{id: 1, name: "Lionel"}}

  """

  @typedoc """
  The domain name that forms part of the location an action can be registered to.
  Domain names are generally descriptive names such as 'User', 'Book', 'Equipment' etc.
  """
  @type domain :: atom

  @typedoc """
  The address that forms the other part of the location an action can be registered to.
  Address names are usually generic names that reappear across domains, such as 'New', 'Find', 'Sell', etc.
  """
  @type address :: atom

  @typedoc """
  A location consists of a domain and an address, and is used to register and obtain actions.
  """
  @type location :: {domain, address}

  @typedoc """
  The response obtained by `Locator.locate/1`, which will either be the action wrapped in an :ok tuple,
  or a string explaining what domain or address could not be found, wrapped in an error tuple.
  """
  @type response :: {:ok, Locator.Action.t()} | {:error, String.t()}

  @typedoc """
  The options that can be passed into the use macro.
  - layers: a list of layers this module will be attached to.
  - settings: middleware and layer settings defined on a module using `Entangle.Seed`.
  """
  @type option ::
          {:layers, Layers.layers() | Layers.layer_query()}
          | {:settings, Entangle.Seed.t()}
  @type options :: [option]

  @doc """
  The function used to find an action by domain name and address.
  The callback will be automatically defined upon using `Locator`.
  """
  @callback locate(location) :: response

  @doc false
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      seed =
        Keyword.get(opts, :settings)
        |> Option.return()
        |> Option.map(fn
          %Entangle.Seed{} = settings -> settings
          settings -> settings.settings()
        end)
        |> Option.or_else(Entangle.Seed.default_settings())

      use Entangle.Entangler, seed: seed
      import Locator, only: :macros
      @behaviour Locator

      Module.register_attribute(__MODULE__, :domains, accumulate: true)

      @impl Locator
      entangle(:locate, [
        branch(&__MODULE__.do_locate/1)
      ])

      @before_compile Locator
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    %Entangle.Seed{layers: layers, layer_mask: layer_mask} =
      Module.get_attribute(env.module, :settings)

    domains =
      Module.get_attribute(env.module, :domains)
      |> Enum.filter(fn {_, address_registry, options} ->
        Keyword.get(options, :layers)
        |> Option.return()
        |> Option.or_else(address_registry.active_layers())
        |> Option.flatten()
        |> Option.map(&Layers.enabled?(layers, layer_mask, &1))
        |> Option.or_else(true)
      end)
      |> Enum.map(fn {domain, address_registry, _} -> {domain, address_registry} end)
      |> Enum.into(%{})

    quote do
      @doc false
      def do_locate({domain, address} = location) do
        unquote(Macro.escape(domains))[domain]
        |> Option.return()
        |> Option.map(fn address_registry -> address_registry.locate(location) end)
        |> Option.or_else(
          {:error, "Domain not found! " <> to_string(domain) <> ":" <> to_string(address)}
        )
      end
    end
  end

  @doc """
  Macro to register a domain in the form of a `Locator.AddressRegistry`.
  """
  @spec domain(domain, Locator.AddressRegistry.t(), options) :: Macro.t()
  defmacro domain(domain, address_registry, options \\ []) do
    quote do
      @domains {unquote(domain), unquote(address_registry), unquote(options)}
    end
  end
end
