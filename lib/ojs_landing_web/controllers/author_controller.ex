defmodule OjsLandingWeb.AuthorController do
  use OjsLandingWeb, :controller

  def my_submissions(conn, %{"currentViewId" => view_id} = _params) do
    user = conn.assigns.current_user
    all_submissions = OjsLanding.Submission.get_by_author(user.username)

    filtered_submissions = case view_id do
      "active" -> Enum.filter(all_submissions, fn s -> s.status == :active end)
      "revisions-requested" -> Enum.filter(all_submissions, fn s -> s.status == :revisions_requested end)
      "revisions-submitted" -> Enum.filter(all_submissions, fn s -> s.status == :revisions_submitted end)
      "incomplete" -> Enum.filter(all_submissions, fn s -> s.status == :incomplete end)
      "scheduled" -> Enum.filter(all_submissions, fn s -> s.status == :scheduled end)
      "published" -> Enum.filter(all_submissions, fn s -> s.status == :published end)
      "declined" -> Enum.filter(all_submissions, fn s -> s.status == :declined end)
      _ -> all_submissions
    end

    conn
    |> put_root_layout(false)
    |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
    |> render(:my_submissions,
      submissions: filtered_submissions,
      all_submissions: all_submissions,
      current_view: view_id,
      total_submissions: length(all_submissions),
      user: user)
  end

  def my_submissions(conn, _params) do
    user = conn.assigns.current_user
    all_submissions = OjsLanding.Submission.get_by_author(user.username)

    conn
    |> put_root_layout(false)
    |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
    |> render(:my_submissions,
      submissions: all_submissions,
      all_submissions: all_submissions,
      current_view: "active",
      total_submissions: length(all_submissions),
      user: user)
  end

  def new_submission(conn, _params) do
    conn
    |> put_root_layout(false)
    |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
    |> render(:new_submission)
  end

  def create_submission(conn, _params) do
    user = conn.assigns.current_user

    submission = %OjsLanding.Submission{
      id: System.unique_integer([:positive]),
      author_username: user.username,
      title: "",
      abstract: "",
      status: :incomplete,
      files: [],
      contributors: [],
      created_at: DateTime.utc_now()
    }

    conn
    |> put_session(:current_submission, submission)
    |> put_flash(:info, "Submission created successfully")
    |> redirect(to: "/submission/#{submission.id}")
  end

  def edit_submission(conn, %{"id" => id}) do
    submission = %OjsLanding.Submission{
      id: String.to_integer(id),
      author_username: conn.assigns.current_user.username,
      title: "",
      abstract: "",
      status: :incomplete,
      files: [],
      contributors: []
    }

    conn
    |> put_root_layout(false)
    |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
    |> render(:edit_submission, submission: submission, current_tab: "details")
  end

  def update_submission(conn, %{"id" => id, "submission" => _params}) do
    conn
    |> put_flash(:info, "Submission updated successfully")
    |> redirect(to: "/submission/#{id}")
  end

  def saved_submission(conn, %{"id" => _id}) do
    conn
    |> put_flash(:info, "Submission saved for later")
    |> redirect(to: "/dashboard/mySubmissions?currentViewId=incomplete")
  end
end
