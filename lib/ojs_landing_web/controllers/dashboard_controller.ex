defmodule OjsLandingWeb.DashboardController do
  use OjsLandingWeb, :controller

  def index(conn, _params) do
    user = conn.assigns.current_user

    # Redirect berdasarkan role user
    cond do
      user.role == :author ->
        redirect(conn, to: "/dashboard/mySubmissions")

      user.role == :editor ->
        redirect(conn, to: "/dashboard/editorial")

      user.role == :reviewer ->
        redirect(conn, to: "/dashboard/reviewAssignments")

      user.role == :admin ->
        redirect(conn, to: "/admin")

      true ->
        conn
        |> put_root_layout(false)
        |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
        |> render(:index, user: user)
    end
  end
end
