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
    conn
    |> put_root_layout(html: {OjsLandingWeb.Layouts, :admin})
    |> render(:settings, page_title: "Site Settings")
  end

  def wizard(conn, %{"id" => id}) do
    render(conn, :wizard, wizard_id: id)
  end

  def system_info(conn, _params) do
    conn
    |> put_root_layout(html: {OjsLandingWeb.Layouts, :admin})
    |> render(:system_info, page_title: "System Information")
  end

  def php_info(conn, _params) do
    conn
    |> put_root_layout(html: {OjsLandingWeb.Layouts, :admin})
    |> render(:php_info, page_title: "PHP Information")
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
    conn
    |> put_root_layout(html: {OjsLandingWeb.Layouts, :admin})
    |> render(:jobs,
      page_title: "Jobs",
      page_subtitle: "View the queued jobs waiting to be executed"
    )
  end

  def failed_jobs(conn, _params) do
    conn
    |> put_root_layout(html: {OjsLandingWeb.Layouts, :admin})
    |> render(:failed_jobs,
      page_title: "Failed Jobs",
      page_subtitle: "View details of jobs that failed to execute"
    )
  end

  def failed_job_details(conn, %{"id" => id}) do
    failed_job = OjsLandingWeb.AdminHTML.failed_job(id)

    conn
    |> put_root_layout(html: {OjsLandingWeb.Layouts, :admin})
    |> render(:failed_job_details,
      job_id: id,
      failed_job: failed_job,
      page_title: "Failed Job Details",
      page_subtitle: "Details for a job that failed to execute"
    )
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
