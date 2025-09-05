# Candid

Candid is a binary encoding format for the Internet Computer (ICP).

This library allows to encode and decode Candid messages.

## Installation

This package can be installed
by adding `candid` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:candid, "~> 1.0.0"}
  ]
end
```

## Usage

```elixir
type_spec = [{:vec, {:record, [{0, :blob}, {1, :blob}]}}]

messages = [
  {"key1", "hello world"},
  {"key2," "hello candid"}
]

^messages = Candid.encode_parameters(type_spec, messages)
|> Candid.decode_parameters()
```

## Support types and shorthands:

For convenience there are type shorthands for :variant, and :record
- Record: `%{name => type_value}` e.g. %{a: :text}
- Variant: `[type]` e.g. `[{:ok, :text}, :error]`

Other complex types have to be defined as tuples:
- Opt: `{:opt, type}` e.g. `{:opt, :nat}`
- Vec: `{:vec, type}` e.g. `{:vec, :nat}`

And simple types are just atoms:
- `:null`
- `:bool`
- `:nat` (`:nat8`, `:nat16`, `:nat32`, `:nat64`)
- `:int` (`:int8`, `:int16`, `:int32`, `:int64`)
- `:float32`, `:float64`
- `:text`
- `:principal`
- `:blob`
- `:empty`


## Completion

This library does not yet support loading of .did file specifications. PRs and contributions to extend this library are welcome though!

## Documentation

The documentation for this library can be found at [https://hexdocs.pm/candid](https://hexdocs.pm/candid).
