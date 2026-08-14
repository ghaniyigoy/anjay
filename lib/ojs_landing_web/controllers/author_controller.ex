defmodule OjsLandingWeb.AuthorController do
  use OjsLandingWeb, :controller

  alias OjsLanding.Submission

  # Submission wizard tabs, driven by the ?tab= query parameter
  @tabs ["details", "files", "contributors", "editors", "review"]

  # OJS-style dashboard views for authors (currentViewId => label + status filter)
  @views [
    %{id: "active", label: "Active submissions", status: :active},
    %{id: "revisions-requested", label: "Revisions requested", status: :revisions_requested},
    %{id: "revisions-submitted", label: "Revisions submitted", status: :revisions_submitted},
    %{id: "incomplete-submissions", label: "Incomplete submissions", status: :incomplete},
    %{id: "scheduled", label: "Scheduled for publication", status: :scheduled},
    %{id: "published", label: "Published", status: :published},
    %{id: "declined", label: "Declined", status: :declined}
  ]

  @default_view "active"

  def my_submissions(conn, %{"currentViewId" => view_id} = _params) do
    case conn.assigns.current_user do
      nil ->
        redirect_to_login(conn, "Silakan login terlebih dahulu untuk melihat submission Anda.")

      user ->
        all_submissions = Submission.get_by_author(user.username)
        view = normalize_view_id(view_id)

        filtered_submissions = Enum.filter(all_submissions, &(&1.status == view.status))

        render_dashboard(conn, filtered_submissions, all_submissions, view.id, user)
    end
  end

  def my_submissions(conn, _params) do
    my_submissions(conn, %{"currentViewId" => @default_view})
  end

  def new_submission(conn, _params) do
    case conn.assigns.current_user do
      nil ->
        redirect_to_login(conn, "Silakan login terlebih dahulu untuk membuat submission.")

      user ->
        all_submissions = Submission.get_by_author(user.username)

        conn
        |> put_root_layout(false)
        |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
        |> render(:new_submission,
          user: user,
          all_submissions: all_submissions,
          views: @views,
          current_view: @default_view
        )
    end
  end

  def create_submission(conn, params) do
    case conn.assigns.current_user do
      nil ->
        redirect_to_login(conn, "Silakan login terlebih dahulu untuk membuat submission.")

      user ->
        title = get_in(params, ["submission", "title"]) || ""

        if String.trim(title) == "" do
          conn
          |> put_root_layout(false)
          |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
          |> render(:new_submission,
            user: user,
            all_submissions: Submission.get_by_author(user.username),
            views: @views,
            current_view: @default_view,
            title: title,
            form_error:
              "Judul wajib diisi, Submission Checklist dan Privacy Consent harus dicentang."
          )
        else
          submission = Submission.create(user.username, title)

          conn
          |> put_flash(
            :info,
            "Submission #{submission.id} telah dibuat. Lengkapi detail submission untuk melanjutkan."
          )
          |> redirect(to: submission_path(submission.id, "details"))
        end
    end
  end

  def edit_submission(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user
    tab = current_tab(params)

    case {user, Submission.get(id)} do
      {nil, _} ->
        redirect_to_login(conn, "Silakan login terlebih dahulu untuk melihat submission.")

      {_, nil} ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/mySubmissions")

      {user, submission} ->
        conn
        |> put_root_layout(false)
        |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
        |> render(:edit_submission,
          submission: submission,
          current_tab: tab,
          tabs: @tabs,
          user: user,
          all_submissions: Submission.get_by_author(user.username),
          views: @views
        )
    end
  end

  def update_submission(conn, %{"id" => id, "submission" => submission_params} = params) do
    tab = current_tab(params)

    case {conn.assigns.current_user, Submission.update(id, submission_params)} do
      {nil, _} ->
        redirect_to_login(conn, "Silakan login terlebih dahulu untuk memperbarui submission.")

      {_, {:ok, _submission}} ->
        message =
          if submission_params["submit_to_journal"] in ["1", "true"] do
            Submission.set_status(id, :active)
            "Submission #{id} berhasil dikirim ke jurnal!"
          else
            "Submission #{id} berhasil disimpan."
          end

        conn
        |> put_flash(:info, message)
        |> redirect(to: submission_path(id, tab))

      {_, {:error, :not_found}} ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/mySubmissions")
    end
  end

  def saved_submission(conn, %{"id" => id}) do
    conn
    |> put_flash(:info, "Submission #{id} disimpan untuk nanti.")
    |> redirect(to: "/dashboard/mySubmissions?currentViewId=incomplete-submissions")
  end

  defp redirect_to_login(conn, message) do
    conn
    |> put_flash(:error, message)
    |> redirect(to: "/login")
  end

  defp render_dashboard(conn, submissions, all_submissions, view_id, user) do
    conn
    |> put_root_layout(false)
    |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
    |> render(:my_submissions,
      submissions: submissions,
      all_submissions: all_submissions,
      current_view: view_id,
      views: @views,
      total_submissions: length(all_submissions),
      user: user
    )
  end

  defp normalize_view_id(view_id) do
    Enum.find(@views, fn view -> view.id == view_id end) ||
      Enum.find(@views, &(&1.id == @default_view))
  end

  defp current_tab(params) do
    tab = Map.get(params, "tab", "details")

    if tab in @tabs do
      tab
    else
      "details"
    end
  end

  defp submission_path(id, tab), do: "/submission/wizard/#{id}?tab=#{tab}"
end
