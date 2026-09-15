defmodule OjsLandingWeb.AuthorController do
  use OjsLandingWeb, :controller

  alias OjsLanding.Submission
  alias OjsLandingWeb.AuthorHTML
  alias OjsLandingWeb.EditorHTML

  # Submission wizard tabs, driven by the ?tab= query parameter
  @tabs ["details", "files", "contributors", "editors", "review"]

  @workflow_menus [
    {"workflow_1", "Submission"},
    {"workflow_3_1", "Review Round 1"},
    {"workflow_4", "Copyediting"},
    {"workflow_5", "Production"}
  ]

  @publication_menus [
    {"publication_titleAbstract", "Title & Abstract"},
    {"publication_metadata", "Metadata"},
    {"publication_citations", "References"},
    {"publication_jats", "JATS"},
    {"publication_galleys", "Galleys"},
    {"publication_issue", "Issue"},
    {"publication_license", "License"}
  ]

  @default_menu "workflow_1"

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

      (move_id = submission_params["move_contributor_id"]) &&
          is_binary(submission_params["move_dir"]) ->
        handle_contributor_move(conn, id, move_id, submission_params["move_dir"])

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
    user = conn.assigns.current_user

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
        |> render(:saved_submission,
          submission: submission,
          user: user,
          author_name: author_display_name(submission, user),
          all_submissions: Submission.get_by_author(user.username),
          views: @views,
          current_view: @default_view,
          resume_tab: first_incomplete_tab(submission)
        )
    end
  end

  def add_discussion(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    cond do
      is_nil(user) ->
        redirect_to_login(conn, "Silakan login terlebih dahulu.")

      is_nil(Submission.get(id)) ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/mySubmissions")

      true ->
        author =
          case user do
            %{given_name: given, family_name: family} -> String.trim("#{given} #{family}")
            name when is_binary(name) -> name
            _ -> "Author"
          end

        menu = normalize_menu(params["workflowMenuKey"])

        if EditorHTML.other_discussion_participants(Submission.get(id)) == [] do
          conn
          |> put_flash(
            :error,
            "Belum ada editor yang ditugaskan, sehingga diskusi belum dapat dimulai."
          )
          |> redirect(to: "/submission/#{id}/workflow?workflowMenuKey=#{menu}")
        else
          case Submission.add_discussion(id, %{
                 "subject" => params["subject"] || "Discussion",
                 "message" => params["message"] || "",
                 "author" => author
               }) do
            {:ok, _submission} ->
              conn
              |> put_flash(:info, "Discussion added.")
              |> redirect(to: "/submission/#{id}/workflow?workflowMenuKey=#{menu}")

            {:error, :not_found} ->
              conn
              |> put_flash(:error, "Submission tidak ditemukan.")
              |> redirect(to: "/dashboard/mySubmissions")
          end
        end
    end
  end

  def add_editor_reply(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    cond do
      is_nil(user) ->
        redirect_to_login(conn, "Silakan login terlebih dahulu.")

      is_nil(Submission.get(id)) ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/mySubmissions")

      true ->
        menu = normalize_menu(params["workflowMenuKey"])
        message = params["message"] || ""

        if String.trim(AuthorHTML.strip_html(message)) == "" do
          conn
          |> put_flash(:error, "Pesan tidak boleh kosong.")
          |> redirect(to: "/submission/#{id}/workflow?workflowMenuKey=#{menu}")
        else
          case Submission.add_editor_reply(id, author_display_name(nil, user), message) do
            {:ok, _submission} ->
              conn
              |> put_flash(:info, "Message added.")
              |> redirect(to: "/submission/#{id}/workflow?workflowMenuKey=#{menu}")

            {:error, :not_found} ->
              conn
              |> put_flash(:error, "Submission tidak ditemukan.")
              |> redirect(to: "/dashboard/mySubmissions")
          end
        end
    end
  end

  def author_workflow(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    case {user, Submission.get(id)} do
      {nil, _} ->
        redirect_to_login(conn, "Silakan login terlebih dahulu untuk melihat submission.")

      {_, nil} ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/mySubmissions")

      {user, submission} ->
        assignments = author_review_assignments(submission)
        row = author_to_row(submission)

        conn
        |> put_root_layout(false)
        |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
        |> put_view(EditorHTML)
        |> render(:workflow,
          submission: submission,
          row: row,
          active_menu: normalize_menu(params["workflowMenuKey"]),
          workflow_menus: @workflow_menus,
          publication_menus: @publication_menus,
          review_assignments: assignments,
          issues: OjsLanding.Issue.all(),
          current_view: "active",
          prev_submission_id: nil,
          next_submission_id: nil,
          pub_form:
            Phoenix.Component.to_form(
              %{
                "title" => submission.title || "",
                "subtitle" => submission.subtitle || "",
                "abstract" => submission.abstract || "",
                "keywords" => submission.keywords || "",
                "language" => submission.language || "",
                "section" => submission.section || "",
                "references" => submission.references || ""
              },
              as: :publication
            ),
          user: user,
          mode: :author
        )
    end
  end

  defp author_display_name(_submission, user) do
    name =
      [user.given_name, user.family_name]
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.join(" ")

    if name == "", do: user.username, else: name
  end

  defp first_incomplete_tab(submission) do
    Enum.find(@tabs, fn tab -> !wizard_tab_done?(tab, submission) end) || "review"
  end

  defp wizard_tab_done?("details", submission),
    do: is_binary(submission.title) and submission.title != ""

  defp wizard_tab_done?("files", submission), do: length(submission.files || []) > 0
  defp wizard_tab_done?("contributors", submission), do: length(submission.contributors || []) > 0
  defp wizard_tab_done?("editors", submission), do: length(submission.editors || []) > 0

  defp wizard_tab_done?("review", submission) do
    wizard_tab_done?("details", submission) and wizard_tab_done?("files", submission) and
      wizard_tab_done?("contributors", submission)
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
          |> redirect(to: "/submission/wizard/#{id}/saved")
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
    ensure_default_contributor(id, conn.assigns.current_user)

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

  defp handle_contributor_move(conn, id, move_id, dir) do
    case Submission.move_contributor(id, move_id, dir) do
      {:ok, _submission} ->
        conn
        |> redirect(to: "/submission/wizard/#{id}?tab=contributors&view=order")

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/mySubmissions")
    end
  end

  def set_primary_contact(conn, %{"id" => id, "contributor_id" => contributor_id}) do
    case {conn.assigns.current_user, Submission.get(id)} do
      {nil, _} ->
        redirect_to_login(conn, "Silakan login terlebih dahulu untuk memperbarui submission.")

      {_, nil} ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/mySubmissions")

      {_user, _submission} ->
        case Submission.set_primary_contact(id, contributor_id) do
          {:ok, _submission} ->
            conn
            |> put_flash(:info, "Primary contact berhasil diperbarui.")
            |> redirect(to: submission_path(id, "contributors"))

          {:error, :not_found} ->
            conn
            |> put_flash(:error, "Kontributor tidak ditemukan.")
            |> redirect(to: submission_path(id, "contributors"))
        end
    end
  end

  def edit_file(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    cond do
      is_nil(user) ->
        conn
        |> put_status(401)
        |> json(%{ok: false, error: "Silakan login terlebih dahulu."})

      is_nil(Submission.get(id)) ->
        conn
        |> put_status(404)
        |> json(%{ok: false, error: "Submission tidak ditemukan."})

      true ->
        file_id = params["file_id"] || params["fileId"]
        name = params["name"] || params["filename"] || ""

        case Submission.rename_file(id, file_id, name) do
          {:ok, _submission} ->
            conn
            |> put_status(200)
            |> json(%{ok: true, filename: name})

          {:error, :invalid_name} ->
            conn
            |> put_status(422)
            |> json(%{ok: false, error: "Nama file wajib diisi."})

          {:error, :not_found} ->
            conn
            |> put_status(404)
            |> json(%{ok: false, error: "File tidak ditemukan."})
        end
    end
  end

  # Persist the current user as the primary contributor when the submission has no
  # stored contributors yet. Without this, the submitting author (shown as a virtual
  # default row) would silently disappear/revert once a real contributor is added.
  defp ensure_default_contributor(_id, nil), do: :ok

  defp ensure_default_contributor(id, user) do
    submission = Submission.get(id)

    if submission && submission.contributors in [nil, []] do
      default = AuthorHTML.default_contributor(user)

      Submission.update_contributor(id, user.id, %{
        "given_name" => default.given_name,
        "family_name" => default.family_name,
        "preferred_public_name" => default.preferred_public_name || "",
        "email" => default.email,
        "country" => default.country,
        "bio_statement" => default.bio_statement || "",
        "affiliation" => default.affiliation,
        "role" => default.role |> Atom.to_string(),
        "primary" => "true",
        "public_list" => "true"
      })
    end

    :ok
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

          action == "save" || submission_params["save_status"] == "draft" ->
            redirect(conn, to: "/submission/wizard/#{id}/saved")

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

  # --- Author read-only workflow helpers ------------------------------------

  defp normalize_menu(menu) do
    valid = Enum.map(@workflow_menus ++ @publication_menus, &elem(&1, 0))
    if menu in valid, do: menu, else: @default_menu
  end

  defp author_review_assignments(%Submission{title: title})
       when is_binary(title) and title != "" do
    Enum.filter(OjsLanding.ReviewerAssignment.all(), &(&1.title == title))
  end

  defp author_review_assignments(_submission), do: []

  defp author_to_row(submission) do
    user = OjsLanding.User.find_by_username(submission.author_username)

    %{
      id: submission.id,
      title: title_or_placeholder(submission.title),
      author: author_display_name(submission, user),
      assigned_to: "author",
      status: submission.status,
      stage: submission.stage || :submission,
      days: days_since(Map.get(submission, :created_at)),
      reviews_overdue: false,
      has_editor: (Map.get(submission, :editors) || []) != [],
      has_reviewers: false,
      needs_submission_complete: false
    }
  end

  defp title_or_placeholder(title) when title in [nil, ""], do: "(Tanpa judul)"
  defp title_or_placeholder(title), do: title

  defp days_since(nil), do: 0

  defp days_since(%DateTime{} = datetime) do
    max(0, Date.diff(Date.utc_today(), DateTime.to_date(datetime)))
  end

  defp days_since(_), do: 0
end
