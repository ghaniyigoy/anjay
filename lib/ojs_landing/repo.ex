defmodule OjsLanding.Repo do
  use Ecto.Repo,
    otp_app: :ojs_landing,
    adapter: Ecto.Adapters.Postgres
end
