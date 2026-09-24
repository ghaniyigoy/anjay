defmodule OjsLandingWeb.EditorController do
  use OjsLandingWeb, :controller

  alias OjsLanding.Submission

  # OJS 3.5-style workflow menu keys (?workflowMenuKey=...)
  @default_menu "workflow_1"

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

  # ============================================
  # EDITORIAL DASHBOARD (OJS 3.5-style routing)
  #
  # /dashboard/editorial?workflowSubmissionId=1&currentViewId=assigned-to-me&workflowMenuKey=workflow_1
  # opens the workflow view of a single submission at the given menu key.
  # ============================================

  def editorial(conn, %{"workflowSubmissionId" => wf_id} = params) do
    user = conn.assigns.current_user

    case {user, Submission.get(wf_id)} do
      {nil, _} ->
        conn
        |> put_flash(:error, "Silakan login terlebih dahulu untuk mengakses halaman ini.")
        |> redirect(to: "/login")

      {_, nil} ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/editorial")

      {user, submission} ->
        assignments = review_assignments_for(submission)
        all_subs = get_editorial_submissions()
        sub_ids = Enum.map(all_subs, & &1.id)
        current_idx = Enum.find_index(sub_ids, &(&1 == submission.id))

        prev_id = if current_idx, do: Enum.at(sub_ids, current_idx + 1)
        next_id = if current_idx, do: Enum.at(sub_ids, current_idx - 1)

        conn
        |> put_root_layout(false)
        |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
        |> render(:workflow,
          mode: :editor,
          submission: submission,
          row: to_editorial_row(submission),
          active_menu: normalize_menu(params["workflowMenuKey"]),
          workflow_menus: @workflow_menus,
          publication_menus: @publication_menus,
          review_assignments: assignments,
          reviewers:
            OjsLanding.User.all()
            |> Enum.filter(&(&1.role == :reviewer))
            |> Enum.map(fn u -> reviewer_json(u) end),
          ap_users:
            OjsLanding.User.all()
            |> Enum.map(fn u -> reviewer_json(u) end),
          ap_users_json:
            OjsLanding.User.all()
            |> Enum.map(fn u -> reviewer_json(u) end)
            |> Jason.encode!(),
          issues: OjsLanding.Issue.all(),
          current_view: params["currentViewId"] || "assigned-to-me",
          prev_submission_id: prev_id,
          next_submission_id: next_id,
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
          user: user
        )
    end
  end

  def editorial(conn, %{"currentViewId" => view_id} = _params) do
    user = conn.assigns.current_user

    if is_nil(user) do
      conn
      |> put_flash(:error, "Silakan login terlebih dahulu untuk mengakses halaman ini.")
      |> redirect(to: "/login")
    else
      all_submissions = get_editorial_submissions()

      filtered_submissions =
        case view_id do
          "assigned-to-me" ->
            Enum.filter(all_submissions, fn s ->
              OjsLandingWeb.EditorHTML.assigned_to_user?(s, user)
            end)

          "active" ->
            Enum.filter(all_submissions, fn s -> s.status in [:active, :under_review] end)

          "needs-editor" ->
            Enum.filter(all_submissions, fn s -> s.stage == :needs_editor end)

          "initial-review" ->
            Enum.filter(all_submissions, fn s -> s.stage == :initial_review end)

          "needs-reviews" ->
            Enum.filter(all_submissions, fn s -> s.stage == :needs_reviews end)

          "awaiting-reviews" ->
            Enum.filter(all_submissions, fn s -> s.stage == :awaiting_reviews end)

          "reviews-submitted" ->
            Enum.filter(all_submissions, fn s -> s.stage == :reviews_submitted end)

          "reviews-overdue" ->
            Enum.filter(all_submissions, fn s -> s.reviews_overdue end)

          "revisions-submitted" ->
            Enum.filter(all_submissions, fn s -> s.stage == :revisions_submitted end)

          "external-review" ->
            Enum.filter(all_submissions, fn s -> s.stage == :external_review end)

          "copyediting" ->
            Enum.filter(all_submissions, fn s -> s.stage == :copyediting end)

          "production" ->
            Enum.filter(all_submissions, fn s -> s.stage == :production end)

          "scheduled" ->
            Enum.filter(all_submissions, fn s -> s.status == :scheduled end)

          "published" ->
            Enum.filter(all_submissions, fn s -> s.status == :published end)

          "declined" ->
            Enum.filter(all_submissions, fn s -> s.status == :declined end)

          _ ->
            all_submissions
        end

      conn
      |> put_root_layout(false)
      |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
      |> render(:editorial,
        submissions: filtered_submissions,
        all_submissions: all_submissions,
        current_view: view_id || "assigned-to-me",
        user: user,
        ap_users_json:
          OjsLanding.User.all()
          |> Enum.map(fn u -> reviewer_json(u) end)
          |> Jason.encode!(),
        ap_submissions_json:
          filtered_submissions
          |> Enum.map(fn row ->
            sub = OjsLanding.Submission.get(row.id)

            %{
              "id" => row.id,
              "title" => row.title,
              "author" => row.author,
              "username" => author_username(sub),
              "affiliation" => author_affiliation(sub)
            }
          end)
          |> Jason.encode!()
      )
    end
  end

  def editorial(conn, _params) do
    editorial(conn, %{"currentViewId" => "assigned-to-me"})
  end

  # Editorial activity log for a single submission (derived from store data).
  def activity(conn, %{"id" => id} = params) do
    user = conn.assigns.current_user

    case {user, Submission.get(id)} do
      {nil, _} ->
        conn
        |> put_flash(:error, "Silakan login terlebih dahulu untuk mengakses halaman ini.")
        |> redirect(to: "/login")

      {_, nil} ->
        conn
        |> put_flash(:error, "Submission tidak ditemukan.")
        |> redirect(to: "/dashboard/editorial")

      {user, submission} ->
        assignments = review_assignments_for(submission)

        conn
        |> put_root_layout(false)
        |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
        |> render(:activity,
          submission: submission,
          row: to_editorial_row(submission),
          events: OjsLandingWeb.EditorHTML.activity_events(submission, assignments),
          current_view: params["currentViewId"] || "active",
          workflow_menu:
            OjsLandingWeb.EditorHTML.default_workflow_menu_for_stage(
              submission.stage || :submission
            ),
          user: user
        )
    end
  end

  # ============================================
  # SEND FOR REVIEW — EMAIL NOTIFICATION WIZARD
  #
  # Step 1 (Notify Authors) renders the email composition page. Step 2
  # (Select Files) lets the editor confirm which submission files to attach
  # before the real POST /send-to-review transitions the submission.
  # ============================================

  def send_to_review_email(conn, %{"id" => id} = params) do
    case guard_editor(conn) do
      :redirected ->
        conn

      :ok ->
        case Submission.get(id) do
          nil ->
            conn
            |> put_flash(:error, "Submission tidak ditemukan.")
            |> redirect(to: "/dashboard/editorial")

          submission ->
            view = params["currentViewId"] || "active"
            recipients = primary_contact(submission)

            conn
            |> put_root_layout(false)
            |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
            |> render(:send_to_review_email,
              submission: submission,
              row: to_editorial_row(submission),
              current_view: view,
              recipients: recipients,
              recipient_name: recipient_text(recipients),
              email_templates: send_to_review_templates(),
              user: conn.assigns.current_user
            )
        end
    end
  end

  def send_to_review_files(conn, %{"id" => id} = params) do
    case guard_editor(conn) do
      :redirected ->
        conn

      :ok ->
        case Submission.get(id) do
          nil ->
            conn
            |> put_flash(:error, "Submission tidak ditemukan.")
            |> redirect(to: "/dashboard/editorial")

          submission ->
            view = params["currentViewId"] || "active"

            conn
            |> put_root_layout(false)
            |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
            |> render(:send_to_review_files,
              submission: submission,
              row: to_editorial_row(submission),
              current_view: view,
              user: conn.assigns.current_user
            )
        end
    end
  end

  # Primary contact (or first) contributor that emails should be addressed to.
  defp primary_contact(submission) do
    submission.contributors
    |> Enum.sort_by(&(Map.get(&1, :primary) == true), :desc)
    |> List.first()
  end

  defp recipient_text(nil) do
    "Author"
  end

  defp recipient_text(contributor) do
    name =
      String.trim(
        "#{Map.get(contributor, :given_name) || ""} #{Map.get(contributor, :family_name) || ""}"
      )

    if name == "", do: Map.get(contributor, :full_name) || "Author", else: name
  end

  defp send_to_review_templates do
    [
      %{
        name: "Submission Acknowledgment",
        subject: "Your submission has been received",
        description: "Sent on submission to confirm receipt."
      },
      %{
        name: "Submission Sent for Review",
        subject: "Your submission has been sent for review",
        description: "Notifies the author that the submission entered peer review."
      },
      %{
        name: "Review Request",
        subject: "You have been selected as a reviewer",
        description: "Invites a reviewer to accept or decline the assignment."
      },
      %{
        name: "Review Completed",
        subject: "Thank you for completing your review",
        description: "Acknowledges a submitted review."
      }
    ]
  end

  # Save publication fields (Title & Abstract / Metadata / References tabs)
  def save_publication(conn, %{"id" => id, "publication" => publication_params} = params) do
    if is_nil(conn.assigns.current_user) do
      conn
      |> put_flash(:error, "Silakan login terlebih dahulu untuk mengakses halaman ini.")
      |> redirect(to: "/login")
    else
      menu = normalize_menu(params["workflowMenuKey"])
      view = params["currentViewId"] || "assigned-to-me"

      case Submission.update(id, publication_params) do
        {:ok, submission} ->
          conn
          |> put_flash(:info, "Publication details updated.")
          |> redirect(to: OjsLandingWeb.EditorHTML.workflow_menu_path(submission.id, view, menu))

        {:error, :not_found} ->
          conn
          |> put_flash(:error, "Submission tidak ditemukan.")
          |> redirect(to: "/dashboard/editorial")
      end
    end
  end

  # ============================================
  # EDITOR WORKFLOW ACTIONS
  # ============================================

  def send_to_review(conn, %{"id" => id} = params) do
    case guard_editor(conn) do
      :redirected ->
        conn

      :ok ->
        view = params["currentViewId"] || "assigned-to-me"

        with {:ok, submission} <- Submission.set_status(id, :active),
             {:ok, submission} <- Submission.set_stage(submission.id, :external_review) do
          conn
          |> put_flash(:info, "Submission #{id} sent to external review.")
          |> redirect(
            to: OjsLandingWeb.EditorHTML.workflow_menu_path(submission.id, view, "workflow_3_1")
          )
        else
          {:error, :not_found} ->
            conn
            |> put_flash(:error, "Submission tidak ditemukan.")
            |> redirect(to: "/dashboard/editorial")
        end
    end
  end

  def request_revisions(conn, %{"id" => id} = params) do
    case guard_editor(conn) do
      :redirected ->
        conn

      :ok ->
        view = params["currentViewId"] || "assigned-to-me"

        with {:ok, submission} <- Submission.set_status(id, :revisions_requested),
             {:ok, submission} <- Submission.set_stage(submission.id, :external_review) do
          conn
          |> put_flash(:info, "Revisions requested for submission #{id}.")
          |> redirect(
            to: OjsLandingWeb.EditorHTML.workflow_menu_path(submission.id, view, "workflow_3_1")
          )
        else
          {:error, :not_found} ->
            conn
            |> put_flash(:error, "Submission tidak ditemukan.")
            |> redirect(to: "/dashboard/editorial")
        end
    end
  end

  def accept_submission(conn, %{"id" => id} = params) do
    case guard_editor(conn) do
      :redirected ->
        conn

      :ok ->
        view = params["currentViewId"] || "assigned-to-me"

        with {:ok, submission} <- Submission.set_status(id, :scheduled),
             {:ok, submission} <- Submission.set_stage(submission.id, :production) do
          conn
          |> put_flash(:info, "Submission #{id} accepted and scheduled for publication.")
          |> redirect(
            to: OjsLandingWeb.EditorHTML.workflow_menu_path(submission.id, view, "workflow_5")
          )
        else
          {:error, :not_found} ->
            conn
            |> put_flash(:error, "Submission tidak ditemukan.")
            |> redirect(to: "/dashboard/editorial")
        end
    end
  end

  def decline_submission(conn, %{"id" => id} = params) do
    case guard_editor(conn) do
      :redirected ->
        conn

      :ok ->
        view = params["currentViewId"] || "assigned-to-me"

        case Submission.set_status(id, :declined) do
          {:ok, _submission} ->
            conn
            |> put_flash(:info, "Submission #{id} has been declined.")
            |> redirect(to: "/dashboard/editorial?currentViewId=#{view}")

          {:error, :not_found} ->
            conn
            |> put_flash(:error, "Submission tidak ditemukan.")
            |> redirect(to: "/dashboard/editorial")
        end
    end
  end

  def assign_reviewer(conn, %{"id" => id, "reviewer_name" => reviewer_name} = params) do
    case guard_editor(conn) do
      :redirected ->
        conn

      :ok ->
        view = params["currentViewId"] || "assigned-to-me"

        case Submission.get(id) do
          nil ->
            conn
            |> put_flash(:error, "Submission tidak ditemukan.")
            |> redirect(to: "/dashboard/editorial")

          submission ->
            OjsLanding.ReviewerAssignment.create(%{
              "title" => submission.title,
              "subtitle" => submission.subtitle || "",
              "abstract" => submission.abstract || "",
              "author" => author_name(submission),
              "reviewer_name" => reviewer_name,
              "section" => submission.section || "",
              "language" => submission.language || "",
              "keywords" => submission.keywords || "",
              "due_date" => Date.add(Date.utc_today(), 14),
              "round" => 1,
              "files" => submission.files || []
            })

            conn
            |> put_flash(:info, "Reviewer #{reviewer_name} assigned to submission #{id}.")
            |> redirect(to: "/dashboard/editorial?currentViewId=#{view}")
        end
    end
  end

  def assign_editor(
        conn,
        %{"submission_id" => id, "user_id" => user_id, "username" => username} = params
      ) do
    case guard_editor(conn) do
      :redirected ->
        conn

      :ok ->
        view = params["currentViewId"] || "active"
        menu = params["workflowMenuKey"]

        case Submission.get(id) do
          nil ->
            conn
            |> put_flash(:error, "Submission tidak ditemukan.")
            |> redirect(to: "/dashboard/editorial")

          _submission ->
            user = OjsLanding.User.find_by_username(username)

            editor_info = %{
              "id" => user_id,
              "username" => username,
              "name" =>
                if(user,
                  do: String.trim("#{user.given_name} #{user.family_name}"),
                  else: username
                ),
              "email" => if(user, do: user.email, else: ""),
              "role" => params["role"] || "editor"
            }

            case Submission.assign_editor(id, editor_info) do
              {:ok, _submission} ->
                conn
                |> put_flash(:info, "Editor #{username} assigned to submission #{id}.")
                |> redirect(to: assign_editor_redirect(id, view, menu))

              {:error, :not_found} ->
                conn
                |> put_flash(:error, "Submission tidak ditemukan.")
                |> redirect(to: "/dashboard/editorial")
            end
        end
    end
  end

  defp assign_editor_redirect(id, view, menu) do
    if is_binary(menu) and menu != "" do
      OjsLandingWeb.EditorHTML.workflow_menu_path(id, view, menu)
    else
      "/dashboard/editorial?currentViewId=#{view}"
    end
  end

  # Add a pre-review discussion thread to a submission (workflow_1 panel).
  def add_discussion(conn, %{"id" => id} = params) do
    case guard_editor(conn) do
      :redirected ->
        conn

      :ok ->
        view = params["currentViewId"] || "assigned-to-me"
        menu = normalize_menu(params["workflowMenuKey"])

        author =
          case conn.assigns.current_user do
            %{given_name: given, family_name: family} -> String.trim("#{given} #{family}")
            name when is_binary(name) -> name
            _ -> "Editor"
          end

        case Submission.add_discussion(id, %{
               "subject" => params["subject"] || "Discussion",
               "message" => params["message"] || "",
               "author" => author
             }) do
          {:ok, submission} ->
            conn
            |> put_flash(:info, "Discussion added.")
            |> redirect(
              to: OjsLandingWeb.EditorHTML.workflow_menu_path(submission.id, view, menu)
            )

          {:error, :not_found} ->
            conn
            |> put_flash(:error, "Submission tidak ditemukan.")
            |> redirect(to: "/dashboard/editorial")
        end
    end
  end

  defp guard_editor(conn) do
    if is_nil(conn.assigns.current_user) do
      conn
      |> put_flash(:error, "Silakan login terlebih dahulu untuk mengakses halaman ini.")
      |> redirect(to: "/login")

      :redirected
    else
      :ok
    end
  end

  defp normalize_menu(menu) do
    valid = Enum.map(@workflow_menus ++ @publication_menus, &elem(&1, 0))
    if menu in valid, do: menu, else: @default_menu
  end

  # Review assignments linked to a submission by matching title.
  defp review_assignments_for(%Submission{title: title})
       when is_binary(title) and title != "" do
    Enum.filter(OjsLanding.ReviewerAssignment.all(), &(&1.title == title))
  end

  defp review_assignments_for(_submission), do: []

  # Data submission asli dari store Submission (hasil submit author)
  defp get_editorial_submissions do
    OjsLanding.Submission.all()
    |> Enum.reject(&(&1.status == :incomplete))
    |> Enum.map(&to_editorial_row/1)
  end

  defp to_editorial_row(submission) do
    assignments = review_assignments_for(submission)

    %{
      id: submission.id,
      title: title_or_placeholder(submission.title),
      author: author_name(submission),
      assigned_to: "editor",
      status: submission.status,
      stage: submission.stage || :submission,
      days: days_since(Map.get(submission, :created_at)),
      reviews_overdue: false,
      has_editor: has_editor?(submission),
      has_reviewers: has_reviewers?(assignments),
      needs_submission_complete: needs_submission_complete?(submission),
      completed_reviews: completed_reviews(assignments)
    }
  end

  defp title_or_placeholder(title) when title in [nil, ""], do: "(Tanpa judul)"
  defp title_or_placeholder(title), do: title

  # Reviewer assignments that have been submitted by the reviewer (status
  # :completed). Each entry drives the green "Review Completed" notification
  # popover shown in the EDITORIAL ACTIVITY column.
  defp completed_reviews(assignments) do
    assignments
    |> Enum.filter(&(&1.status == :completed))
    |> Enum.map(fn a ->
      history = a.review_history || []
      last = List.last(history)
      stamp = a.submitted_at || (last && Map.get(last, :date))

      %{
        assignment_id: a.id,
        reviewer: completed_reviewer(a, last),
        completed_on: normalize_completion_date(stamp),
        completed_at: format_completed_at(stamp),
        recommendation:
          a.recommendation || (last && Map.get(last, :decision)) || "No Recommendation",
        comments_author: a.comments_author,
        comments_editor: a.comments_editor,
        reviewer_files: a.reviewer_files || []
      }
    end)
  end

  defp completed_reviewer(a, last) do
    if a.reviewer_name not in [nil, ""] do
      a.reviewer_name
    else
      (last && Map.get(last, :reviewer)) || "Reviewer"
    end
  end

  defp normalize_completion_date(%DateTime{} = datetime), do: DateTime.to_date(datetime)
  defp normalize_completion_date(%Date{} = date), do: date

  defp normalize_completion_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> Date.utc_today()
    end
  end

  defp normalize_completion_date(_), do: Date.utc_today()

  # Display value for the "Review Details" drawer "Completed" field, e.g.
  # "2026-08-08 14:32" when the exact submission timestamp is known, otherwise
  # just the ISO date.
  defp format_completed_at(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  defp format_completed_at(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")

  defp format_completed_at(value) when is_binary(value) do
    case Date.from_iso8601(String.slice(value, 0, 10)) do
      {:ok, date} -> Calendar.strftime(date, "%Y-%m-%d")
      _ -> "—"
    end
  end

  defp format_completed_at(_), do: "—"

  # Build reviewer JSON payload for the "Add Reviewer" modal. Derives reviewer
  # metrics (review count, last review, current status) from the assignment store.
  defp reviewer_json(user) do
    assignments = reviewer_assignments_for_user(user)

    %{
      "id" => user.id,
      "username" => user.username,
      "email" => user.email,
      "given_name" => user.given_name,
      "family_name" => user.family_name,
      "affiliation" => user.affiliation,
      "role" => user.role,
      "review_count" => Enum.count(assignments, &(&1.status in [:completed, :published])),
      "last_review" => last_review_date(assignments),
      "status" => reviewer_user_status(assignments),
      "active_reviews" =>
        Enum.count(assignments, &(&1.status in [:action_required, :in_progress])),
      "reviews_completed" => Enum.count(assignments, &(&1.status in [:completed, :published])),
      "reviews_declined" => Enum.count(assignments, &(&1.status == :declined)),
      "reviews_cancelled" => 0,
      "days_since_last_review" => days_since_last_review(assignments),
      "avg_days_to_complete" => avg_days_to_complete(assignments),
      "reviewing_interests" => reviewing_interests(user)
    }
  end

  defp days_since_last_review(assignments) do
    assignments
    |> Enum.filter(&(&1.date_assigned != nil))
    |> Enum.map(& &1.date_assigned)
    |> Enum.max(fn -> nil end)
    |> case do
      nil -> 0
      date -> Date.diff(Date.utc_today(), date)
    end
  end

  defp avg_days_to_complete(assignments) do
    durations =
      assignments
      |> Enum.filter(&(&1.submitted_at != nil and &1.date_assigned != nil))
      |> Enum.map(fn a -> Date.diff(a.submitted_at, a.date_assigned) end)

    case durations do
      [] -> 0
      list -> div(Enum.sum(list), length(list))
    end
  end

  defp reviewing_interests(user) do
    interests =
      [
        user.affiliation,
        if(user.role == :reviewer, do: "Peer Review", else: nil)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(", ")

    if interests == "", do: "No interests listed", else: interests
  end

  defp reviewer_assignments_for_user(user) do
    Enum.filter(OjsLanding.ReviewerAssignment.all(), fn a ->
      String.contains?(a.author || "", String.trim("#{user.given_name} #{user.family_name}")) or
        String.contains?(String.trim("#{user.given_name} #{user.family_name}"), a.author || "")
    end)
  end

  defp last_review_date(assignments) do
    assignments
    |> Enum.filter(&(&1.date_assigned != nil))
    |> Enum.map(& &1.date_assigned)
    |> Enum.max(fn -> nil end)
  end

  defp reviewer_user_status(assignments) do
    cond do
      Enum.any?(assignments, &(&1.status in [:action_required, :in_progress])) -> "Busy"
      Enum.any?(assignments, &(&1.status == :completed)) -> "Available"
      true -> "Available"
    end
  end

  # Username author (akun yang mengirim submission). Fallback ke username kontributor.
  defp author_username(submission) do
    case primary_contact(submission) do
      nil ->
        Map.get(submission, :author_username) || ""

      contributor ->
        Map.get(contributor, :username) || Map.get(submission, :author_username) || ""
    end
  end

  # Afiliasi author diambil dari primary contact contributor, lalu fallback ke akun user.
  defp author_affiliation(submission) do
    case primary_contact(submission) do
      nil ->
        account_affiliation(submission)

      contributor ->
        case Map.get(contributor, :affiliation) do
          aff when aff in [nil, ""] -> account_affiliation(submission)
          aff -> aff
        end
    end
  end

  defp account_affiliation(submission) do
    case OjsLanding.User.find_by_username(Map.get(submission, :author_username)) do
      nil -> ""
      user -> user.affiliation || ""
    end
  end

  # Nama author diambil dari contributors submission (primary contact lebih dulu),
  # lalu fallback ke nama akun.
  defp author_name(submission) do
    case contributor_names(submission.contributors) do
      [] -> author_account_name(submission.author_username)
      names -> List.first(names)
    end
  end

  defp contributor_names(contributors) when is_list(contributors) do
    contributors
    |> Enum.sort_by(&(Map.get(&1, :primary) == true), :desc)
    |> Enum.map(&contributor_display_name/1)
    |> Enum.reject(&is_nil/1)
  end

  defp contributor_names(_), do: []

  defp contributor_display_name(contributor) when is_map(contributor) do
    name =
      String.trim("#{Map.get(contributor, :given_name)} #{Map.get(contributor, :family_name)}")

    if name == "", do: nil, else: name
  end

  defp contributor_display_name(_), do: nil

  defp author_account_name(username) do
    case OjsLanding.User.find_by_username(username) do
      nil ->
        username || "Unknown"

      user ->
        String.trim("#{user.given_name} #{user.family_name}")
    end
  end

  defp has_editor?(submission) do
    editors = Map.get(submission, :editors) || []
    editors != []
  end

  defp has_reviewers?(assignments) do
    Enum.any?(assignments, fn a ->
      status = normalize_status(a.status)
      status in [:action_required, :in_progress, :completed]
    end)
  end

  defp normalize_status(status) when is_atom(status), do: status

  defp normalize_status(status) when is_binary(status) do
    String.to_existing_atom(status)
  rescue
    _ -> :unknown
  end

  defp normalize_status(_), do: :unknown

  defp needs_submission_complete?(submission) do
    submission.status == :incomplete or
      (submission.stage in [:submission, nil] and submission.date_submitted == nil)
  end

  defp days_since(nil), do: 0

  defp days_since(%DateTime{} = datetime) do
    max(0, Date.diff(Date.utc_today(), DateTime.to_date(datetime)))
  end

  defp days_since(_), do: 0
end
