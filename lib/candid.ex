defmodule Candid do
  @moduledoc """
  Candid is a binary encoding format for the Internet Computer (ICP).
  https://github.com/dfinity/candid/blob/master/spec/Candid.md

  This module encodes and decodes the format allowing to encode requests
  to the ICP network and decode responses.

  ```elixir
    type_spec = [{:vec, {:record, [{0, :blob}, {1, :blob}]}}]

    messages = [
      {"key1", "hello world"},
      {"key2," "hello candid"}
    ]

    ^messages = Candid.encode_parameters(type_spec, messages)
    |> Candid.decode_parameters()
  ```
  """

  @doc """
  Encodes a list of types and values into a Candid binary parameter string.

  Example:

  ```elixir
  Candid.encode_parameters([:int, :blob], [15, "hello world"])
  ```
  """
  def encode_parameters(types, values) do
    if size(types) != size(values) do
      raise "types and values must have the same length"
    end

    {typemap, definitions} =
      Enum.reduce(values(types), {%{}, []}, fn type, {typemap, definition_table} ->
        if Map.has_key?(typemap, type) do
          {typemap, definition_table}
        else
          {encoding, definition_table} = encode_type(type, definition_table)
          {Map.put(typemap, type, encoding), definition_table}
        end
      end)

    definition_table = encode_list(definitions)
    argument_types = encode_list(values(types), fn type -> typemap[type] end)
    binvalues = encode_type_value({:record, types}, values)
    result = "DIDL" <> definition_table <> argument_types <> binvalues
    {^values, ""} = decode_parameters(result, types)
    result
  end

  def decode_parameters("DIDL" <> term, passed_argument_types \\ nil) do
    {definition_table, rest} = decode_definition_list(term)
    {parsed_argument_types, rest} = decode_list(rest, &decode_type(&1, definition_table))
    argument_types = passed_argument_types || parsed_argument_types

    case decode_type_value({:record, argument_types}, rest, definition_table) do
      {result, rest} when is_tuple(result) ->
        {Tuple.to_list(result), rest}

      {result, rest} ->
        {result, rest}
    end
  end

  def namehash(atom) when is_atom(atom), do: namehash(Atom.to_string(atom))
  def namehash(integer) when is_integer(integer), do: integer

  def namehash(name) do
    # hash(id) = ( Sum_(i=0..k) utf8(id)[i] * 223^(k-i) ) mod 2^32 where k = |utf8(id)|-1
    name
    |> String.to_charlist()
    |> Enum.with_index()
    |> Enum.reduce(0, fn {char, i}, acc ->
      (acc + char * 223 ** (byte_size(name) - i - 1))
      |> rem(4_294_967_296)
    end)
  end

  defp decode_definition_list(term) do
    {len, rest} = LEB128.decode_unsigned!(term)

    if len == 0 do
      {[], rest}
    else
      Enum.reduce(1..len, {[], rest}, fn _n, {definition_table, rest} ->
        {item, rest} = decode_type(rest, definition_table)
        {definition_table ++ [item], rest}
      end)
    end
  end

  defp decode_list(term, fun) do
    {len, rest} = LEB128.decode_unsigned!(term)
    decode_list_items(len, rest, fun, [])
  end

  defp decode_list_items(0, rest, _fun, acc) do
    {acc, rest}
  end

  defp decode_list_items(n, rest, fun, acc) do
    {item, rest} = fun.(rest)
    decode_list_items(n - 1, rest, fun, acc ++ [item])
  end

  defp decode_type_value(
         :nat32,
         <<value::unsigned-little-size(32), rest::binary>>,
         _definition_table
       ),
       do: {value, rest}

  defp decode_type_value(
         :int32,
         <<value::signed-little-size(32), rest::binary>>,
         _definition_table
       ),
       do: {value, rest}

  defp decode_type_value(
         :nat64,
         <<value::unsigned-little-size(64), rest::binary>>,
         _definition_table
       ),
       do: {value, rest}

  defp decode_type_value(
         :int64,
         <<value::signed-little-size(64), rest::binary>>,
         _definition_table
       ),
       do: {value, rest}

  defp decode_type_value(
         :nat8,
         <<value::unsigned-little-size(8), rest::binary>>,
         _definition_table
       ),
       do: {value, rest}

  defp decode_type_value(
         :int8,
         <<value::signed-little-size(8), rest::binary>>,
         _definition_table
       ),
       do: {value, rest}

  defp decode_type_value(
         :nat16,
         <<value::unsigned-little-size(16), rest::binary>>,
         _definition_table
       ),
       do: {value, rest}

  defp decode_type_value(
         :int16,
         <<value::signed-little-size(16), rest::binary>>,
         _definition_table
       ),
       do: {value, rest}

  defp decode_type_value(
         :nat32,
         <<value::unsigned-little-size(32), rest::binary>>,
         _definition_table
       ),
       do: {value, rest}

  defp decode_type_value(
         :int32,
         <<value::signed-little-size(32), rest::binary>>,
         _definition_table
       ),
       do: {value, rest}

  defp decode_type_value(:nat, rest, _definition_table), do: LEB128.decode_unsigned!(rest)
  defp decode_type_value(:int, rest, _definition_table), do: LEB128.decode_unsigned!(rest)
  defp decode_type_value(:null, rest, _definition_table), do: {nil, rest}

  defp decode_type_value({:variant, types}, rest, definition_table) do
    {idx, rest} = LEB128.decode_unsigned!(rest)

    {name, type} =
      Enum.at(types, idx) || raise "unimplemented variant index: #{idx} in #{inspect(types)}"

    {value, rest} = decode_type_value(type, rest, definition_table)
    {{name, value}, rest}
  end

  defp decode_type_value({:record, types}, rest, definition_table) do
    {result, rest} =
      make_tagged_list(types)
      |> Enum.sort_by(fn {name, _} -> namehash(name) end)
      |> Enum.reduce({[], rest}, fn {name, type}, {acc, rest} ->
        # According to spec: https://github.com/dfinity/candid/blob/master/spec/Candid.md#core-grammar
        # M(kv*  : record {<fieldtype>*}) = M(kv : <fieldtype>)*
        # M : (<nat>, <val>) -> <fieldtype> -> i8*
        # M((k,v) : k:<datatype>) = M(v : <datatype>)
        # But it seems there is no field name in the real world responses

        # {^name, rest} = LEB128.decode_unsigned!(rest)
        {value, rest} = decode_type_value(type, rest, definition_table)
        {[{name, value} | acc], rest}
      end)

    if Enum.all?(result, fn {name, _} -> is_integer(name) and name < 256 end) do
      {List.to_tuple(Enum.map(Enum.reverse(result), &elem(&1, 1))), rest}
    else
      {Map.new(result), rest}
    end
  end

  defp decode_type_value(:blob, rest, definition_table) do
    decode_type_value({:vec, :nat8}, rest, definition_table)
  end

  defp decode_type_value({:vec, :nat8}, rest, _definition_table) do
    {len, rest} = LEB128.decode_unsigned!(rest)
    <<binary::binary-size(len), rest::binary>> = rest
    {binary, rest}
  end

  defp decode_type_value(:text, rest, _definition_table) do
    {len, rest} = LEB128.decode_unsigned!(rest)
    <<binary::binary-size(len), rest::binary>> = rest
    {binary, rest}
  end

  defp decode_type_value(:principal, <<1>> <> rest, _definition_table) do
    {len, rest} = LEB128.decode_unsigned!(rest)
    <<binary::binary-size(len), rest::binary>> = rest
    {binary, rest}
  end

  defp decode_type_value({:vec, subtype}, rest, definition_table) do
    decode_list(rest, &decode_type_value(subtype, &1, definition_table))
  end

  defp decode_type_value({:comptype, type}, rest, definition_table) do
    type =
      Enum.at(definition_table, type) ||
        raise "unimplemented comptype: #{inspect(type)} in #{inspect(definition_table)}"

    decode_type_value(type, rest, definition_table)
  end

  defp decode_type_value(type, rest, _definition_table) do
    # https://github.com/dfinity/candid/blob/master/spec/Candid.md#core-grammar
    raise "unimplemented type: #{inspect(type)} rest: #{inspect(rest)}"
  end

  defp encode_list(list, fun \\ fn x -> x end) when is_list(list) do
    len = length(list)
    LEB128.encode_unsigned(len) <> Enum.map_join(list, fun)
  end

  defp encode_type_list(types, definition_table, fun) when is_list(types) do
    {encoding, definition_table} =
      Enum.reduce(types, {"", definition_table}, fn type, {acc, definition_table} ->
        {encoding, definition_table} = fun.(type, definition_table)
        {acc <> encoding, definition_table}
      end)

    len = length(types)
    {LEB128.encode_unsigned(len) <> encoding, definition_table}
  end

  defp encode_type_value(:null, _), do: ""

  defp encode_type_value(:bool, bool),
    do:
      (if bool do
         <<1>>
       else
         <<0>>
       end)

  defp encode_type_value(:nat, nat), do: LEB128.encode_unsigned(nat)
  defp encode_type_value(:int, int), do: LEB128.encode_signed(int)
  defp encode_type_value(:nat8, nat8), do: <<nat8>>
  defp encode_type_value(:nat16, nat16), do: <<nat16::unsigned-little-size(16)>>
  defp encode_type_value(:nat32, nat32), do: <<nat32::unsigned-little-size(32)>>
  defp encode_type_value(:nat64, nat64), do: <<nat64::unsigned-little-size(64)>>
  defp encode_type_value(:int8, int8), do: <<int8>>
  defp encode_type_value(:int16, int16), do: <<int16::signed-little-size(16)>>
  defp encode_type_value(:int32, int32), do: <<int32::signed-little-size(32)>>
  defp encode_type_value(:int64, int64), do: <<int64::signed-little-size(64)>>
  defp encode_type_value(:float32, float32), do: <<float32::signed-little-size(32)>>
  defp encode_type_value(:float64, float64), do: <<float64::signed-little-size(64)>>
  defp encode_type_value(:text, text), do: LEB128.encode_unsigned(byte_size(text)) <> text
  defp encode_type_value(:reserved, _), do: ""
  # defp encode_type_value(:empty, _), do: ""
  defp encode_type_value(:principal, principal),
    do: <<1>> <> LEB128.encode_unsigned(byte_size(principal)) <> principal

  defp encode_type_value({:vec, :nat8}, binary) when is_binary(binary),
    do: LEB128.encode_unsigned(byte_size(binary)) <> binary

  defp encode_type_value({:vec, type}, values),
    do: encode_list(values, &encode_type_value(type, &1))

  defp encode_type_value(:blob, values), do: encode_type_value({:vec, :nat8}, values)
  defp encode_type_value({:opt, _type}, nil), do: <<0>>
  defp encode_type_value({:opt, type}, value), do: <<1>> <> encode_type_value(type, value)

  defp encode_type_value({:record, types}, values) do
    types = make_tagged_list(types)
    values = make_tagged_map(values)

    Enum.sort_by(types, fn {tag, _} -> namehash(tag) end)
    |> Enum.map_join(fn {tag, type} ->
      # Seems in the real world responses, the tag is not encoded
      # LEB128.encode_unsigned(tag) <> encode_type_value(type, value)
      encode_type_value(type, values[tag] || raise("Missing value for tag: #{inspect(tag)}"))
    end)
  end

  defp encode_type_value({:variant, types}, {tag, value}) do
    types = make_tagged_list(types)

    idx =
      Enum.find_index(types, fn {tag1, _type} -> tag == tag1 end) ||
        raise("Missing value for variant: #{inspect(types)}")

    {_tag, type} = Enum.at(types, idx)
    LEB128.encode_unsigned(idx) <> encode_type_value(type, value)
  end

  defp make_tagged_list(tuple) when is_tuple(tuple) do
    Tuple.to_list(tuple)
    |> make_tagged_list()
  end

  defp make_tagged_list(list) when is_list(list) do
    Enum.with_index(list)
    |> Enum.map(fn
      {value, index} -> {index, value}
    end)
  end

  defp make_tagged_list(map) when is_map(map) do
    Map.to_list(map)
  end

  defp make_tagged_map(enum) do
    Map.new(make_tagged_list(enum))
  end

  defp encode_type(:null, definition_table), do: {LEB128.encode_signed(-1), definition_table}
  defp encode_type(:bool, definition_table), do: {LEB128.encode_signed(-2), definition_table}
  defp encode_type(:nat, definition_table), do: {LEB128.encode_signed(-3), definition_table}
  defp encode_type(:int, definition_table), do: {LEB128.encode_signed(-4), definition_table}
  defp encode_type(:nat8, definition_table), do: {LEB128.encode_signed(-5), definition_table}
  defp encode_type(:nat16, definition_table), do: {LEB128.encode_signed(-6), definition_table}
  defp encode_type(:nat32, definition_table), do: {LEB128.encode_signed(-7), definition_table}
  defp encode_type(:nat64, definition_table), do: {LEB128.encode_signed(-8), definition_table}
  defp encode_type(:int8, definition_table), do: {LEB128.encode_signed(-9), definition_table}
  defp encode_type(:int16, definition_table), do: {LEB128.encode_signed(-10), definition_table}
  defp encode_type(:int32, definition_table), do: {LEB128.encode_signed(-11), definition_table}
  defp encode_type(:int64, definition_table), do: {LEB128.encode_signed(-12), definition_table}
  defp encode_type(:float32, definition_table), do: {LEB128.encode_signed(-13), definition_table}
  defp encode_type(:float64, definition_table), do: {LEB128.encode_signed(-14), definition_table}
  defp encode_type(:text, definition_table), do: {LEB128.encode_signed(-15), definition_table}

  defp encode_type(:reserved, definition_table),
    do: {LEB128.encode_signed(-16), definition_table}

  defp encode_type(:empty, definition_table), do: {LEB128.encode_signed(-17), definition_table}

  defp encode_type(:principal, definition_table),
    do: {LEB128.encode_signed(-24), definition_table}

  defp encode_type(:blob, definition_table), do: encode_type({:vec, :nat8}, definition_table)

  defp encode_type({comptype, subtype}, definition_table) when comptype in [:opt, :vec] do
    {subencoding, definition_table} = encode_type(subtype, definition_table)

    encoding =
      case comptype do
        :opt -> LEB128.encode_signed(-18)
        :vec -> LEB128.encode_signed(-19)
      end <> subencoding

    maybe_add_complex_type(encoding, definition_table)
  end

  defp encode_type({:record, subtypes}, definition_table) do
    {encoding, definition_table} =
      make_tagged_list(subtypes)
      |> Enum.sort_by(fn {tag, _} -> namehash(tag) end)
      |> encode_type_list(definition_table, &encode_fieldtype/2)

    encoding = LEB128.encode_signed(-20) <> encoding
    maybe_add_complex_type(encoding, definition_table)
  end

  defp encode_type({:variant, subtypes}, definition_table) do
    {encoding, definition_table} =
      make_tagged_list(subtypes)
      |> Enum.sort_by(fn {tag, _} -> namehash(tag) end)
      |> encode_type_list(definition_table, &encode_fieldtype/2)

    encoding = LEB128.encode_signed(-21) <> encoding
    maybe_add_complex_type(encoding, definition_table)
  end

  defp maybe_add_complex_type(encoding, definition_table) do
    case Enum.find_index(definition_table, fn encoding1 -> encoding1 == encoding end) do
      nil -> {LEB128.encode_signed(length(definition_table)), definition_table ++ [encoding]}
      index -> {LEB128.encode_signed(index), definition_table}
    end
  end

  defp encode_fieldtype({tag, type}, definition_table) do
    {encoding, definition_table} = encode_type(type, definition_table)
    {LEB128.encode_unsigned(namehash(tag)) <> encoding, definition_table}
  end

  defp decode_type(term, definition_table) when is_binary(term) do
    decode_type(LEB128.decode_signed!(term), definition_table)
  end

  defp decode_type({-1, rest}, _definition_table), do: {:null, rest}
  defp decode_type({-2, rest}, _definition_table), do: {:bool, rest}
  defp decode_type({-3, rest}, _definition_table), do: {:nat, rest}
  defp decode_type({-4, rest}, _definition_table), do: {:int, rest}
  defp decode_type({-5, rest}, _definition_table), do: {:nat8, rest}
  defp decode_type({-6, rest}, _definition_table), do: {:nat16, rest}
  defp decode_type({-7, rest}, _definition_table), do: {:nat32, rest}
  defp decode_type({-8, rest}, _definition_table), do: {:nat64, rest}
  defp decode_type({-9, rest}, _definition_table), do: {:int8, rest}
  defp decode_type({-10, rest}, _definition_table), do: {:int16, rest}
  defp decode_type({-11, rest}, _definition_table), do: {:int32, rest}
  defp decode_type({-12, rest}, _definition_table), do: {:int64, rest}
  defp decode_type({-13, rest}, _definition_table), do: {:float32, rest}
  defp decode_type({-14, rest}, _definition_table), do: {:float64, rest}
  defp decode_type({-15, rest}, _definition_table), do: {:text, rest}
  defp decode_type({-16, rest}, _definition_table), do: {:reserved, rest}
  defp decode_type({-17, rest}, _definition_table), do: {:empty, rest}

  defp decode_type({-19, rest}, definition_table) do
    {subtype, rest} = decode_type(rest, definition_table)
    {{:vec, subtype}, rest}
  end

  defp decode_type({-20, rest}, definition_table) do
    {subtypes, rest} = decode_list(rest, &decode_fieldtype(&1, definition_table))
    {{:record, Map.new(subtypes)}, rest}
  end

  defp decode_type({-21, rest}, definition_table) do
    {subtypes, rest} = decode_list(rest, &decode_fieldtype(&1, definition_table))
    {{:variant, Map.new(subtypes)}, rest}
  end

  defp decode_type({-24, rest}, _definition_table), do: {:principal, rest}

  defp decode_type({n, rest}, definition_table) when n >= 0 do
    type = Enum.at(definition_table, n) || {:comptype, n}
    {type, rest}
  end

  defp decode_fieldtype(rest, definition_table) do
    {n, rest} = LEB128.decode_unsigned!(rest)
    {type, rest} = decode_type(rest, definition_table)
    {{n, type}, rest}
  end

  defp size(list) when is_list(list), do: length(list)
  defp size(map) when is_map(map), do: map_size(map)
  defp values(list) when is_list(list), do: list

  defp values(map) when is_map(map) do
    Enum.sort_by(map, fn {n, _} -> namehash(n) end)
    |> Enum.map(fn {_, v} -> v end)
  end
end
