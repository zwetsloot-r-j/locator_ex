# Locator

`Locator` is a module to manage application flow by registering actions containing logic to locations defined by 'domain' and 'address'.
  A locator contains one or more 'domains', which themselves consist of multiple actions registered by 'address'. 
  This allows for an application to be structured with clear separation of concerns, while still being able to easily re-use generic actions. At the same time, it makes it very easy to swap in and out functionality without changing the interface of the application, and one could even flag actions or domains with layers to automatically enable or disable them based on the environment of config.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `locator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:locator, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/locator](https://hexdocs.pm/locator).

