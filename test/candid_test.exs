defmodule CandidTest do
  use ExUnit.Case
  doctest Candid

  test "greets the world" do
    types = [{:vec, {:record, [{0, :blob}, {1, :blob}]}}]

    values = [
      [
        {"key1", "hello world"},
        {"key2", "hello candid"}
      ]
    ]

    {^values, ""} =
      Candid.encode_parameters(types, values)
      |> Candid.decode_parameters()
  end

  test "samples" do
    {decoded, ""} =
      <<68, 73, 68, 76, 1, 107, 2, 156, 194, 1, 127, 229, 142, 180, 2, 113, 1, 0, 0>>
      |> Candid.decode_parameters()

    ^decoded = [{Candid.namehash("ok"), nil}]

    {[{0, 1}], ""} =
      <<68, 73, 68, 76, 1, 108, 2, 0, 121, 1, 121, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0>>
      |> Candid.decode_parameters()
  end

  test "encode_parameters" do
    assert encode_parameters([:text, :text], ["hello", "world"]) == {["hello", "world"], ""}

    assert encode_parameters([:principal, :text], ["br5f7-7uaaa-aaaaa-qaaca-cai", "hello"]) ==
             {["br5f7-7uaaa-aaaaa-qaaca-cai", "hello"], ""}

    assert encode_parameters([{:record, [:nat, :blob]}], [{1, "hello"}]) ==
             {[{1, "hello"}], ""}

    assert encode_parameters([{:record, %{id: :nat, name: :blob}}], [%{id: 1, name: "hello"}]) ==
             {[%{id: 1, name: "hello"}], ""}
  end

  defp encode_parameters(types, values) do
    Candid.encode_parameters(types, values)
    |> Candid.decode_parameters(types)
  end
end
