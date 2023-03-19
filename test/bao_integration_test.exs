defmodule BaoClientTest do
  use ExUnit.Case
  doctest BaoClient

  alias BaoClient.User
  alias BaoClient.Utils

  # alias Bitcoinex.Secp256k1
  # alias Bitcoinex.Script
  # alias Bitcoinex.Utils

  @bao %{
    host: "http://localhost",
    port: "4000"
  }
  @bao_pubkey "f62cc16cdf81c12edeb6472cacdeea07a5e3e9d240848ce1b6d2e9fe2a309913"

  describe "happy-path" do
    test "get oracle pubkey" do
      res = BaoClient.get_oracle(@bao)
      %{"pubkey" => pubkey} = res
      assert pubkey == @bao_pubkey
    end

    test "2-of-2 barrier oracle" do
      # fetch oracle pubkey
      res = BaoClient.get_oracle(@bao)
      %{"pubkey" => oracle_pubkey} = res

      # CREATE event

      # setup new keys
      {alice_sk, alice_pk} = User.new_key_pair()
      {bob_sk, bob_pk} = User.new_key_pair()

      pubkeys = [alice_pk, bob_pk]

      event_hash = User.calculate_event_hash(pubkeys) |> Base.encode16(case: :lower)

      res = BaoClient.create_event(@bao, pubkeys)

      %{
        "event_hash" => res_event_hash,
        "event_point" => res_event_point,
        "event_signature" => res_event_signature,
        "pubkeys" => res_pubkeys
      } = res

      assert res_event_hash == event_hash
      assert byte_size(res_event_point) == 66
      assert User.verify_event_signature(oracle_pubkey, res_event_point, res_event_signature)
      assert [alice_pk, bob_pk] == res_pubkeys

      # GET event
      res = BaoClient.get_event(@bao, res_event_point)

      %{
        "event_hash" => res2_event_hash,
        "event_point" => res2_event_point,
        "event_signature" => res2_event_signature,
        "pubkeys" => res2_pubkeys,
        "signature_count" => sig_ct
      } = res

      assert res2_event_hash == res_event_hash
      assert res2_event_point == res_event_point
      assert res2_event_signature == res_event_signature
      assert res2_pubkeys == res_pubkeys
      assert sig_ct == 0

      # Add Signatures

      event_hash = Utils.hex_to_int(event_hash)
      # Add Alice Signature
      alice_sig = User.sign_event_hash(alice_sk, event_hash)

      res = BaoClient.add_signature(@bao, res_event_point, alice_pk, alice_sig)

      %{
        "event_hash" => res3_event_hash,
        "event_point" => res3_event_point,
        "event_signature" => res3_event_signature,
        "pubkeys" => res3_pubkeys,
        "signature_count" => sig_ct
      } = res

      # TODO how to check that scalar is NOT included

      assert res3_event_hash == res_event_hash
      assert res3_event_point == res_event_point
      assert res3_event_signature == res_event_signature
      assert res3_pubkeys == res_pubkeys
      assert sig_ct == 1

      # Add Bob Signature
      bob_sig = User.sign_event_hash(bob_sk, event_hash)

      res = BaoClient.add_signature(@bao, res_event_point, bob_pk, bob_sig)

      %{
        "event_point" => res4_event_point,
        "event_scalar" => res_event_scalar,
        "pubkeys" => res4_pubkeys
      } = res

      assert res4_event_point == res_event_point
      assert length(res4_pubkeys) == length(res_pubkeys)
      assert User.verify_event_scalar_with_event_point(res_event_scalar, res4_event_point)
    end
  end

  describe "error handling" do
    test "user puts invalid signature" do
      event_not_found_msg = "event not found"
      bad_signature_msg = "bad request: invalid signature"

      # fetch oracle pubkey
      res = BaoClient.get_oracle(@bao)
      %{"pubkey" => _oracle_pubkey} = res

      # CREATE event

      # setup new keys
      {alice_sk, alice_pk} = User.new_key_pair()
      {bob_sk, bob_pk} = User.new_key_pair()

      pubkeys = [alice_pk, bob_pk]

      event_hash = User.calculate_event_hash(pubkeys) |> Base.encode16(case: :lower)

      res = BaoClient.create_event(@bao, pubkeys)

      %{
        "event_hash" => _res_event_hash,
        "event_point" => res_event_point,
        "event_signature" => _res_event_signature,
        "pubkeys" => _res_pubkeys
      } = res

      event_hash = Utils.hex_to_int(event_hash)
      alice_sig = User.sign_event_hash(alice_sk, event_hash)
      bob_sig = User.sign_event_hash(bob_sk, event_hash)

      # mismatch pubkey/signature
      res = BaoClient.add_signature(@bao, res_event_point, alice_pk, bob_sig)

      %{
        "error" => ^bad_signature_msg
      } = res

      # fake sig
      fake_sig = :crypto.strong_rand_bytes(64) |> Base.encode16(case: :lower)
      res = BaoClient.add_signature(@bao, res_event_point, alice_pk, fake_sig)

      %{
        "error" => ^bad_signature_msg
      } = res

      # PUT valid signature for uninvolved pubkey
      {carol_sk, carol_pk} = User.new_key_pair()
      carol_sig = User.sign_event_hash(carol_sk, event_hash)
      res = BaoClient.add_signature(@bao, res_event_point, carol_pk, carol_sig)

      %{
        "error" => ^event_not_found_msg
      } = res

      # PUT repeat signature (same & different)
      res = BaoClient.add_signature(@bao, res_event_point, alice_pk, alice_sig)

      %{
        "event_hash" => _,
        "event_point" => _,
        "event_signature" => _,
        "pubkeys" => _,
        "signature_count" => sig_ct
      } = res

      assert sig_ct == 1

      res = BaoClient.add_signature(@bao, res_event_point, alice_pk, alice_sig)

      %{
        "event_hash" => _,
        "event_point" => _,
        "event_signature" => _,
        "pubkeys" => _,
        "signature_count" => sig_ct
      } = res

      assert sig_ct == 1
    end

    test "non-existent event" do
      event_not_found_msg = "event not found"

      # GET non-existent event
      fake_event_point = :crypto.strong_rand_bytes(33) |> Base.encode16(case: :lower)
      res = BaoClient.get_event(@bao, fake_event_point)

      %{
        "error" => ^event_not_found_msg
      } = res
    end

    test "incomplete input" do
      event_not_found_msg = "event not found"
      missing_point_param_msg = "bad request: missing point param"

      # get event
      point = "03deadbeef"
      res = BaoClient.get_event(@bao, point)

      %{
        "error" => ^event_not_found_msg
      } = res

      # no event point param
      url = BaoClient.build_url(@bao, "/api/event")
      {:ok, res} = Req.get(url)
      assert res.status == 400

      %{
        "error" => ^missing_point_param_msg
      } = res.body

      missing_pubkeys_field_msg = "bad request: missing pubkeys field"

      # create event
      res = BaoClient.create_event(@bao, nil)

      %{
        "error" => ^missing_pubkeys_field_msg
      } = res

      res = BaoClient.create_event(@bao, [])
      %{
        "error" => ^missing_pubkeys_field_msg
      } = res



      # add signature
    end

    # POST existing, incomplete event
    # POST already complete event
    # GET unknown URL
    # Post empty/non-hex/bad inputs
    # - get event
    # - create event
    # - add signature
    # - event_point
    # - pubkey
    # - signature
    # trailing slashes
  end
end
