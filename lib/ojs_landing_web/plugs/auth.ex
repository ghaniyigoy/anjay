defmodule OjsLandingWeb.Plugs.Auth do
  import Plug.Conn
  import Phoenix.Controller

  def init(opts), do: opts

  def call(conn, :require_admin) do
    user = conn.assigns[:current_user]

    if user && OjsLanding.User.has_role?(user, :admin) do
      conn
    else
      conn
      |> put_flash(:error, "Akses ditolak. Hanya admin yang dapat mengakses halaman ini.")
      |> redirect(to: "/login")
      |> halt()
    end
  end

  def call(conn, _opts) do
    user_id = get_session(conn, :current_user)

    if user_id do
      user = OjsLanding.User.find_by_username(user_id)
      assign(conn, :current_user, user)
    else
      assign(conn, :current_user, nil)
    end
  end
end
