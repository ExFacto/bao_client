defmodule BaoClient.Utils do
  alias Bitcoinex.Utils

  def hash(data), do: Utils.double_sha256(data)

  def encode16(data), do: Base.encode16(data, case: :lower)
  def decode16(data), do: Base.decode16(data, case: :lower)
  def decode16!(data), do: Base.decode16!(data, case: :lower)

  def hex_to_int(data), do: decode16!(data) |> :binary.decode_unsigned()

  def int_to_hex(data, sz \\ 32) do
    data
    |> :binary.encode_unsigned()
    |> Utils.pad(sz, :leading)
    |> encode16()
  end
end
