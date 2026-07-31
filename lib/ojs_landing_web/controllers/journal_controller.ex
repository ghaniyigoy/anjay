defmodule OjsLandingWeb.JournalController do
  use OjsLandingWeb, :controller
  alias OjsLanding.Journal

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
      |> render(:show, journal: journal, journal_path: journal_path, page_title: "Current Issue - #{journal.title}")
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
      |> render(:archives, journal: journal, journal_path: journal_path, page_title: "Archives - #{journal.title}")
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
      |> render(:about, journal: journal, journal_path: journal_path, page_title: "About - #{journal.title}")
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
      |> render(:submissions, journal: journal, journal_path: journal_path, page_title: "Submissions - #{journal.title}")
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
      |> render(:editorial_masthead, journal: journal, journal_path: journal_path, page_title: "Editorial Masthead - #{journal.title}")
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
      |> render(:privacy, journal: journal, journal_path: journal_path, page_title: "Privacy Statement - #{journal.title}")
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
      |> render(:contact, journal: journal, journal_path: journal_path, page_title: "Contact - #{journal.title}")
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
      |> render(:issues, journal: journal, journal_path: journal_path, page_title: "Issues - #{journal.title}")
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
      |> render(:issue_view, journal: journal, issue_id: issue_id, journal_path: journal_path, page_title: "Issue #{issue_id}")
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  def article_view(conn, %{"journal_path" => journal_path, "article_id" => article_id}) do
    journal = find_journal_by_path(journal_path)
    if journal do
      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:article_view, journal: journal, article_id: article_id, journal_path: journal_path)
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  defp find_journal_by_path(path) do
    journals = Journal.all()
    Enum.find(journals, fn journal ->
      journal_path = journal.path || String.replace(String.downcase(journal.title), " ", "_")
      journal_path == path
    end)
  end
end
