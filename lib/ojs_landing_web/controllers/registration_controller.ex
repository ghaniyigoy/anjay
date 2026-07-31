defmodule OjsLandingWeb.RegistrationController do
  use OjsLandingWeb, :controller

  def new(conn, %{"journal_path" => journal_path} = _params) do
    render(conn, :new, error: nil, journal_path: journal_path)
  end

  def new(conn, _params) do
    render(conn, :new, error: nil, journal_path: nil)
  end

  def create(conn, %{"journal_path" => journal_path} = params) do
    if params["password"] != params["password_confirm"] do
      render(conn, :new, error: "Password dan konfirmasi password tidak cocok", journal_path: journal_path)
    else
      case OjsLanding.User.register(params) do
        {:ok, user} ->
          conn
          |> put_session(:current_user, user.username)
          |> put_flash(:info, "Registrasi berhasil! Selamat datang, #{user.given_name}")
          |> redirect(to: "/#{journal_path}")

        {:error, message} ->
          render(conn, :new, error: message, journal_path: journal_path)
      end
    end
  end

  def create(conn, params) do
    if params["password"] != params["password_confirm"] do
      render(conn, :new, error: "Password dan konfirmasi password tidak cocok", journal_path: nil)
    else
      case OjsLanding.User.register(params) do
        {:ok, user} ->
          conn
          |> put_session(:current_user, user.username)
          |> put_flash(:info, "Registrasi berhasil! Selamat datang, #{user.given_name}")
          |> redirect(to: "/")

        {:error, message} ->
          render(conn, :new, error: message, journal_path: nil)
      end
    end
  end
end
