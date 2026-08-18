defmodule OjsLandingWeb.DashboardController do
  use OjsLandingWeb, :controller

  def index(conn, _params) do
    user = conn.assigns.current_user

    # Redirect berdasarkan role user
    cond do
      OjsLanding.User.has_role?(user, :admin) ->
        redirect(conn, to: "/admin")

      OjsLanding.User.has_role?(user, :editor) ->
        redirect(conn, to: "/dashboard/editorial")

      OjsLanding.User.has_role?(user, :reviewer) ->
        redirect(conn, to: "/dashboard/reviewAssignments")

      OjsLanding.User.has_role?(user, :author) ->
        redirect(conn, to: "/dashboard/mySubmissions")

      true ->
        conn
        |> put_root_layout(false)
        |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
        |> render(:index, user: user)
    end
  end
end
