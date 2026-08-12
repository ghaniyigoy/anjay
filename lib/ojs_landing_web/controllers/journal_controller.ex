defmodule OjsLandingWeb.JournalController do
  use OjsLandingWeb, :controller
  alias OjsLanding.Journal
  alias OjsLanding.Submission

  def index(conn, _params) do
    journals = Journal.all()
    render(conn, :index, journals: journals, journal_path: nil)
  end

  def redirect_old_journal(conn, %{"id" => id}) do
    journal = Journal.get!(String.to_integer(id))
    journal_path = journal.path || String.replace(String.downcase(journal.title), " ", "_")
    redirect(conn, to: "/#{journal_path}")
  end

  def show(conn, %{"journal_path" => journal_path}) do
    journal = find_journal_by_path(journal_path)

    if journal do
      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:show, journal: journal, journal_path: journal_path, page_title: journal.title)
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  def current_issue(conn, %{"journal_path" => journal_path}) do
    journal = find_journal_by_path(journal_path)

    if journal do
      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:show,
        journal: journal,
        journal_path: journal_path,
        page_title: "Current Issue - #{journal.title}"
      )
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  def archives(conn, %{"journal_path" => journal_path}) do
    journal = find_journal_by_path(journal_path)

    if journal do
      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:archives,
        journal: journal,
        journal_path: journal_path,
        page_title: "Archives - #{journal.title}"
      )
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  def about(conn, %{"journal_path" => journal_path}) do
    journal = find_journal_by_path(journal_path)

    if journal do
      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:about,
        journal: journal,
        journal_path: journal_path,
        page_title: "About - #{journal.title}"
      )
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  def submissions(conn, %{"journal_path" => journal_path}) do
    journal = find_journal_by_path(journal_path)

    if journal do
      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:submissions,
        journal: journal,
        journal_path: journal_path,
        page_title: "Submissions - #{journal.title}"
      )
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  def editorial_masthead(conn, %{"journal_path" => journal_path}) do
    journal = find_journal_by_path(journal_path)

    if journal do
      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:editorial_masthead,
        journal: journal,
        journal_path: journal_path,
        page_title: "Editorial Masthead - #{journal.title}"
      )
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  def privacy(conn, %{"journal_path" => journal_path}) do
    journal = find_journal_by_path(journal_path)

    if journal do
      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:privacy,
        journal: journal,
        journal_path: journal_path,
        page_title: "Privacy Statement - #{journal.title}"
      )
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  def contact(conn, %{"journal_path" => journal_path}) do
    journal = find_journal_by_path(journal_path)

    if journal do
      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:contact,
        journal: journal,
        journal_path: journal_path,
        page_title: "Contact - #{journal.title}"
      )
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  def issues(conn, %{"journal_path" => journal_path}) do
    journal = find_journal_by_path(journal_path)

    if journal do
      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:issues,
        journal: journal,
        journal_path: journal_path,
        page_title: "Issues - #{journal.title}"
      )
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  def issue_view(conn, %{"journal_path" => journal_path, "issue_id" => issue_id}) do
    journal = find_journal_by_path(journal_path)

    if journal do
      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:issue_view,
        journal: journal,
        issue_id: issue_id,
        journal_path: journal_path,
        page_title: "Issue #{issue_id}"
      )
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  def article_view(conn, %{"journal_path" => journal_path, "article_id" => article_id}) do
    journal = find_journal_by_path(journal_path)

    if journal do
      article = resolve_article(journal, article_id)

      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:article_view,
        journal: journal,
        article: article,
        article_id: article_id,
        journal_path: journal_path,
        page_title: article_cast(article, :title) || "Article - #{journal.title}"
      )
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  defp resolve_article(%{articles: articles}, article_id) when is_binary(article_id) do
    case String.downcase(article_id) do
      "view" ->
        resolve_article(%{articles: articles}, nil)

      _ ->
        case Integer.parse(article_id) do
          {id, ""} -> resolve_article(%{articles: articles}, id)
          _ -> List.first(articles)
        end
    end
  end

  defp resolve_article(%{articles: articles}, article_id) when is_integer(article_id) do
    Enum.find(articles, &(&1.id == article_id)) || List.first(articles)
  end

  defp resolve_article(%{articles: articles}, nil), do: List.first(articles)

  defp article_cast(nil, _field), do: nil
  defp article_cast(article, field), do: Map.get(article, field)

  defp find_journal_by_path(path) do
    journals = Journal.all()

    Enum.find(journals, fn journal ->
      journal_path = journal.path || String.replace(String.downcase(journal.title), " ", "_")
      journal_path == path
    end)
  end

  def submission_workflow(conn, %{"journal_path" => journal_path} = params) do
    journal = find_journal_by_path(journal_path)

    if journal do
      submissions = Submission.all()
      submission = resolve_submission(params["id"], submissions)

      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:submission,
        journal: journal,
        journal_path: journal_path,
        submissions: submissions,
        submission: submission,
        page_title: "Submission #{submission.id} - #{journal.title}"
      )
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  defp resolve_submission(id, submissions) do
    case id && Submission.get(id) do
      nil -> Enum.find(submissions, &(&1.id == 8)) || List.first(submissions)
      submission -> submission
    end
  end
end
