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

## Documentation

The documentation for this library can be found at [https://hexdocs.pm/candid](https://hexdocs.pm/candid).
