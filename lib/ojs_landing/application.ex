defmodule OjsLanding.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
	OjsLanding.Repo,
      OjsLandingWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:ojs_landing, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OjsLanding.PubSub},
      OjsLanding.User,
      OjsLanding.Submission,

      # Start to serve requests, typically the last entry
      OjsLandingWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: OjsLanding.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    OjsLandingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
