defmodule CandidTest do
  use ExUnit.Case
  doctest Candid

  test "greets the world" do
    types = [{:vec, {:record, [:blob, :blob]}}]

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

    type = {:record, %{zone_id: :text, rpc_host: :text, rpc_path: :text}}
    values = %{zone_id: "zone_id", rpc_host: "rpc_host", rpc_path: "rpc_path"}
    assert encode_parameters([type], [values]) == {[values], ""}
  end

  test "function parameter ordering" do
    assert encode_parameters(%{a: :text, b: :text}, %{a: "hello", b: "world"}) ==
             {%{a: "hello", b: "world"}, ""}

    type = [:principal, :text, :text, :text]
    values = {"br5f7-7uaaa-aaaaa-qaaca-cai", "rpc_host", "rpc_path", "zone_id"}

    assert encode_parameters([{:record, type}], [values]) ==
             {[values], ""}
  end

  test "complex record" do
    type = %{zone_id: :text, rpc_host: :text, rpc_path: :text, cycles_requester_id: :principal}

    values = %{
      zone_id: "zone_id",
      rpc_host: "rpc_host",
      rpc_path: "rpc_path",
      cycles_requester_id: "br5f7-7uaaa-aaaaa-qaaca-cai"
    }

    assert encode_parameters([{:record, type}], [values]) ==
             {[values], ""}
  end

  test "variant" do
    type = {:variant, %{number: :int, paragraph: :text, nothing: :null}}

    assert encode_parameters([type], [{:number, 7}]) == {[{:number, 7}], ""}
    assert encode_parameters([type], [{:paragraph, "abc"}]) == {[{:paragraph, "abc"}], ""}
    assert encode_parameters([type], [{:nothing, nil}]) == {[{:nothing, nil}], ""}
  end

  defp encode_parameters(types, values) do
    Candid.encode_parameters(types, values)
    |> Candid.decode_parameters(types)
  end
end
