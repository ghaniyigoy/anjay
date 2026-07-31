defmodule OjsLandingWeb.AdminController do
  use OjsLandingWeb, :controller
  plug OjsLandingWeb.Plugs.Auth, :require_admin

  def index(conn, _params) do
    render(conn, :index)
  end

  def contexts(conn, _params) do
    journals = OjsLanding.Journal.all()
    render(conn, :contexts, journals: journals)
  end

  def settings(conn, _params) do
    render(conn, :settings)
  end

  def wizard(conn, %{"id" => id}) do
    render(conn, :wizard, wizard_id: id)
  end

  def system_info(conn, _params) do
    render(conn, :system_info)
  end

  def php_info(conn, _params) do
    render(conn, :php_info)
  end

  def expire_sessions(conn, _params) do
    conn
    |> put_flash(:info, "All user sessions have been expired")
    |> redirect(to: "/admin")
  end

  def clear_template_cache(conn, _params) do
    conn
    |> put_flash(:info, "Template cache cleared")
    |> redirect(to: "/admin")
  end

  def clear_data_cache(conn, _params) do
    conn
    |> put_flash(:info, "Data cache cleared")
    |> redirect(to: "/admin")
  end

  def jobs(conn, _params) do
    render(conn, :jobs)
  end

  def failed_jobs(conn, _params) do
    render(conn, :failed_jobs)
  end

  def failed_job_details(conn, %{"id" => id}) do
    render(conn, :failed_job_details, job_id: id)
  end

  def create_journal(conn, _params) do
    render(conn, :create_journal)
  end

  def create_journal_submit(conn, _params) do
    conn
    |> put_flash(:info, "Journal created successfully!")
    |> redirect(to: "/admin/contexts")
  end
end
