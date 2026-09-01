defmodule OjsLandingWeb.AuthorController do
  use OjsLandingWeb, :controller

  alias OjsLanding.Submission
  alias OjsLandingWeb.AuthorHTML

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
        sub_params = Map.get(params, "submission", %{})
        title = sub_params["title"] || ""
        section = sub_params["section"] || "Artikel Penelitian"
        language = sub_params["language"] || "id"
        checklist_agreed = sub_params["checklist_agreed"] in ["1", "true", "on"]
        privacy_consent = sub_params["privacy_consent"] in ["1", "true", "on"]
        comments_to_editor = sub_params["comments_to_editor"] || ""

        if String.trim(title) == "" || !checklist_agreed || !privacy_consent do
          conn
          |> put_root_layout(false)
          |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
          |> render(:new_submission,
            user: user,
            all_submissions: Submission.get_by_author(user.username),
            views: @views,
            current_view: @default_view,
            title: title,
            section: section,
            language: language,
            comments_to_editor: comments_to_editor,
            form_error:
              "Judul wajib diisi, Submission Checklist dan Privacy Consent harus dicentang."
          )
        else
          submission = Submission.create(user.username, title)

          Submission.update(submission.id, %{
            "section" => section,
            "language" => language,
            "checklist_agreed" => checklist_agreed,
            "privacy_consent" => privacy_consent,
            "comments_to_editor" => comments_to_editor
          })

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
          contributor_view: normalize_contributor_view(Map.get(params, "view")),
          editing_contributor:
            find_contributor(
              submission,
              Map.get(params, "view"),
              Map.get(params, "contributor_id"),
              user
            ),
          tabs: @tabs,
          user: user,
          all_submissions: Submission.get_by_author(user.username),
          views: @views
        )
    end
  end

  def update_submission(conn, %{"id" => id, "submission" => submission_params} = params) do
    tab = current_tab(params)

    cond do
      is_nil(conn.assigns.current_user) ->
        redirect_to_login(conn, "Silakan login terlebih dahulu untuk memperbarui submission.")

      is_binary(submission_params["delete_contributor_id"]) ->
        handle_contributor_delete(conn, id, submission_params["delete_contributor_id"], tab)

      (edit_id = submission_params["contributor_edit_id"]) &&
          is_map(submission_params["contributor_edit"]) ->
        handle_contributor_edit(conn, id, edit_id, submission_params["contributor_edit"], tab)

      true ->
        handle_generic_update(conn, id, submission_params, tab, Map.get(params, "action"))
    end
  end

  def show(conn, %{"id" => id}) do
    case {conn.assigns.current_user, Submission.get(id)} do
      {nil, _} ->
        redirect_to_login(conn, "Silakan login terlebih dahulu untuk melihat submission.")

      {_, nil} ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/mySubmissions")

      {_user, submission} ->
        conn
        |> redirect(to: submission_path(submission.id, "details"))
    end
  end

  def saved_submission(conn, %{"id" => id}) do
    conn
    |> put_flash(:info, "Submission #{id} disimpan untuk nanti.")
    |> redirect(to: "/dashboard/mySubmissions?currentViewId=incomplete-submissions")
  end

  # ============================================
  # MAKE A SUBMISSION: DETAILS (OJS 3.5 wizard)
  # ============================================

  def details(conn, %{"id" => id}) do
    case {conn.assigns.current_user, Submission.get(id)} do
      {nil, _} ->
        redirect_to_login(conn, "Silakan login terlebih dahulu untuk melihat submission.")

      {_, nil} ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/mySubmissions")

      {_user, submission} ->
        render_details(conn, submission, %{}, AuthorHTML.submission_to_form(submission))
    end
  end

  def save_details(conn, %{"id" => id, "submission" => submission_params} = params) do
    action = Map.get(params, "action", "save")
    submission = Submission.get(id)
    errors = validate_details(submission_params)

    cond do
      is_nil(conn.assigns.current_user) ->
        redirect_to_login(conn, "Silakan login terlebih dahulu untuk memperbarui submission.")

      is_nil(submission) ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/mySubmissions")

      map_size(errors) > 0 ->
        render_details(
          conn,
          submission,
          errors,
          AuthorHTML.submission_params_to_form(submission_params)
        )

      true ->
        Submission.update(id, submission_params)

        if action == "continue" do
          conn
          |> put_flash(:info, "Submission #{id} berhasil disimpan.")
          |> redirect(to: "/submission/wizard/#{id}?tab=files")
        else
          conn
          |> put_flash(:info, "Submission #{id} disimpan untuk nanti.")
          |> redirect(to: "/dashboard/mySubmissions?currentViewId=incomplete-submissions")
        end
    end
  end

  defp render_details(conn, submission, errors, form) do
    conn
    |> put_root_layout(false)
    |> put_layout(html: {OjsLandingWeb.Layouts, :submission})
    |> render(:details, submission: submission, errors: errors, form: form)
  end

  defp validate_details(submission_params) do
    title = submission_params["title"] || ""
    abstract = submission_params["abstract"] || ""

    %{}
    |> maybe_add_error("title", "A title is required.", title)
    |> maybe_add_error("abstract", "An abstract is required.", abstract)
  end

  defp maybe_add_error(errors, key, message, value) when is_binary(value) do
    if String.trim(value) == "" do
      Map.put(errors, key, message)
    else
      errors
    end
  end

  defp maybe_add_error(errors, _key, _message, _value), do: errors

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

  defp normalize_contributor_view(view) when view in ["order", "preview", "list", "edit"],
    do: String.to_atom(view)

  defp normalize_contributor_view(_view), do: :list

  defp find_contributor(_submission, view, _contributor_id, _user) when view != "edit", do: nil

  defp find_contributor(submission, "edit", contributor_id, user) do
    case Integer.parse(contributor_id || "") do
      {int, _} ->
        cond do
          Enum.any?(submission.contributors || [], &(&1.id == int)) ->
            Enum.find(submission.contributors || [], &(&1.id == int))

          submission.contributors in [nil, []] and int == user.id ->
            AuthorHTML.default_contributor(user)

          int == AuthorHTML.next_contributor_id(submission, user) ->
            AuthorHTML.new_contributor(int)

          true ->
            nil
        end

      :error ->
        nil
    end
  end

  defp handle_contributor_delete(conn, id, contributor_id, tab) do
    case Submission.delete_contributor(id, contributor_id) do
      {:ok, _submission} ->
        conn
        |> put_flash(:info, "Kontributor berhasil dihapus.")
        |> redirect(to: submission_path(id, tab))

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/mySubmissions")
    end
  end

  defp handle_contributor_edit(conn, id, edit_id, fields, tab) do
    case Submission.update_contributor(id, edit_id, fields) do
      {:ok, _submission} ->
        conn
        |> put_flash(:info, "Kontributor berhasil diperbarui.")
        |> redirect(to: submission_path(id, tab))

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/mySubmissions")
    end
  end

  defp handle_generic_update(conn, id, submission_params, tab, action) do
    case Submission.update(id, submission_params) do
      {:ok, _submission} ->
        cond do
          submission_params["submit_to_journal"] in ["1", "true"] ->
            Submission.set_status(id, :active)

            conn
            |> put_flash(:info, "Submission #{id} berhasil dikirim ke jurnal!")
            |> redirect(to: "/dashboard/mySubmissions")

          action == "continue" ->
            continue_from(conn, id, submission_params, tab)

          true ->
            conn
            |> put_flash(:info, "Submission #{id} berhasil disimpan.")
            |> redirect(to: submission_path(id, tab))
        end

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/mySubmissions")
    end
  end

  defp continue_from(conn, id, submission_params, tab) do
    case validate_step(submission_params, tab) do
      :ok ->
        conn
        |> put_flash(:info, "Submission #{id} berhasil disimpan.")
        |> redirect(to: submission_path(id, next_tab(tab)))

      {:error, message} ->
        conn
        |> put_flash(:error, message)
        |> redirect(to: submission_path(id, tab))
    end
  end

  defp validate_step(submission_params, "details") do
    errors = validate_details(submission_params)

    if map_size(errors) == 0 do
      :ok
    else
      {:error, errors |> Map.values() |> Enum.join(" ")}
    end
  end

  defp validate_step(_submission_params, _tab), do: :ok

  defp next_tab("details"), do: "files"
  defp next_tab("files"), do: "contributors"
  defp next_tab("contributors"), do: "editors"
  defp next_tab("editors"), do: "review"
  defp next_tab(tab), do: tab

  defp submission_path(id, tab), do: "/submission/wizard/#{id}?tab=#{tab}"
end
