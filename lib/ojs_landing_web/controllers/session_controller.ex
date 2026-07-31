defmodule OjsLandingWeb.SessionController do
  use OjsLandingWeb, :controller

  def new(conn, _params) do
    journal_path = conn.params["journal_path"]
    render(conn, :new, error: nil, journal_path: journal_path)
  end

  def create(conn, params) do
    identifier = params["email"] || params["username"] || ""
    password = params["password"] || ""

    case OjsLanding.User.verify_login(identifier, password) do
      {:ok, user} ->
        conn
        |> put_session(:current_user, user.username)
        |> put_flash(:info, "Selamat datang, #{user.given_name}!")
        # SEMUA user diarahkan ke homepage setelah login
        |> redirect(to: "/")

      {:error, message} ->
        journal_path = conn.params["journal_path"]
        render(conn, :new, error: message, journal_path: journal_path)
    end
  end

  def delete(conn, _params) do
    conn
    |> delete_session(:current_user)
    |> put_flash(:info, "Anda telah logout")
    |> redirect(to: "/")
  end
end
