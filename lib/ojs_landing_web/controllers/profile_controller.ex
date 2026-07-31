defmodule OjsLandingWeb.ProfileController do
  use OjsLandingWeb, :controller

  def index(conn, _params) do
    user = conn.assigns.current_user
    render(conn, :index, user: user)
  end
end
