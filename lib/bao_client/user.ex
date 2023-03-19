defmodule BaoClient.User do
  alias Bitcoinex.Secp256k1
  alias Bitcoinex.Script
  alias BaoClient.Utils

  def new_rand_int() do
    32
    |> :crypto.strong_rand_bytes()
    |> :binary.decode_unsigned()
  end

  def new_privkey() do
    {:ok, sk} =
      new_rand_int()
      |> Secp256k1.PrivateKey.new()

    Secp256k1.force_even_y(sk)
  end

  # utility functions for using Bao as a client/user
  def calculate_event_hash(pubkeys) do
    pubkeys
    |> Enum.map(fn pk ->
      {:ok, point} = Secp256k1.Point.lift_x(pk)
      point
    end)
    |> sort_pubkeys()
    |> Enum.reduce(<<>>, fn pk, acc -> acc <> Secp256k1.Point.x_bytes(pk) end)
    |> Utils.hash()
  end

  def new_key_pair() do
    sk = new_privkey()
    pk = Secp256k1.PrivateKey.to_point(sk)
    {sk, Secp256k1.Point.x_hex(pk)}
  end

  def sort_pubkeys(pubkeys) do
    Script.lexicographical_sort_pubkeys(pubkeys)
  end

  def verify_event_signature(oracle_pubkey, event_point, event_signature) do
    {:ok, oracle_pk} = Secp256k1.Point.lift_x(oracle_pubkey)
    sighash = calculate_event_point_sighash(event_point)
    {:ok, signature} = Secp256k1.Signature.parse_signature(event_signature)
    Secp256k1.Schnorr.verify_signature(oracle_pk, sighash, signature)
  end

  def calculate_event_point_sighash(event_point) do
    {:ok, event_point} = Secp256k1.Point.parse_public_key(event_point)

    Secp256k1.Point.sec(event_point)
    |> Utils.hash()
    |> :binary.decode_unsigned()
  end

  def sign_event_hash(sk = %Secp256k1.PrivateKey{}, event_hash) do
    {:ok, sig} = Secp256k1.Schnorr.sign(sk, event_hash, new_rand_int())
    Secp256k1.Signature.to_hex(sig)
  end

  def verify_event_scalar_with_event_point(event_scalar, event_point) do
    {:ok, sk} =
      event_scalar
      |> Utils.hex_to_int()
      |> Secp256k1.PrivateKey.new()

    {:ok, pk} = Secp256k1.Point.parse_public_key(event_point)
    Secp256k1.PrivateKey.to_point(sk) == pk
  end
end
