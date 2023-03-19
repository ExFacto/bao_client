defmodule BaoClient do
  @moduledoc """
  Documentation for `BaoClient`.
  """

  use Supervisor

  @type bao_server_args() :: [
          host: :inet.hostname(),
          port: :inet.port_number()
        ]

  # @spec start_link(btc_rpc_args()) :: Supervisor.on_start()
  # def start_link(args) do
  #   Supervisor.start_link(__MODULE__, args, name: __MODULE__)
  # end

  # @impl Supervisor
  # def init(args) do
  #   Supervisor.init(children(args), strategy: :one_for_one)
  # end

  # defp children(args) do
  #   children = [
  #     # might be unnecessary
  #     {Registry, [keys: :unique, name: BaoClient.ServerRegistry]}
  #   ]

  #   if args[:server] != nil do
  #     add_server_clients(children, args)
  #   else
  #     config = Config.from_args(args)
  #     add_server_client(children, config)
  #   end
  # end

  # defp add_server_client(children, config) do
  #   children ++ [{BaoClient.Client, [config: config]}]
  # end

  #### Bao API ####

  @oracle_endpoint "/api/oracle"
  @event_endpoint "/api/event"

  def build_url(args, endpoint), do: "#{args.host}:#{args.port}#{endpoint}"

  def get_oracle(args) do
    url = build_url(args, @oracle_endpoint)
    {:ok, res} = Req.get(url)
    res.body
  end

  def create_event(args, pubkeys) do
    url = build_url(args, @event_endpoint)
    {:ok, res} = Req.post(url, json: %{pubkeys: pubkeys})
    res.body
  end

  def get_event(args, point) do
    url = build_url(args, @event_endpoint)
    {:ok, res} = Req.get(url, params: [point: point])
    res.body
  end

  def add_signature(args, event_point, user_pubkey, signature) do
    body = %{
      event_point: event_point,
      pubkey: user_pubkey,
      signature: signature
    }

    url = build_url(args, @event_endpoint)
    {:ok, res} = Req.put(url, json: body)
    res.body
  end
end
