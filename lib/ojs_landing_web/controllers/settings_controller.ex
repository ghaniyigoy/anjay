defmodule OjsLandingWeb.SettingsController do
  use OjsLandingWeb, :controller
  plug OjsLandingWeb.Plugs.Auth, :require_editor_admin
  alias OjsLanding.Journal
  alias OjsLanding.Issue

  @sections %{
    "context" => %{template: :settings_context, title: "Journal"},
    "website" => %{template: :settings_website, title: "Website"},
    "workflow" => %{template: :settings_workflow, title: "Workflow"},
    "distribution" => %{template: :settings_distribution, title: "Distribution"},
    "access" => %{template: :settings_access, title: "Users & Roles"}
  }

  def index(conn, %{"journal_path" => journal_path}) do
    if find_journal_by_path(journal_path) do
      redirect(conn, to: "/#{journal_path}/management/settings/context")
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  def show(conn, %{"journal_path" => journal_path, "section" => section}) do
    journal = find_journal_by_path(journal_path)

    case {journal, Map.get(@sections, section)} do
      {nil, _} ->
        conn
        |> put_flash(:error, "Journal not found")
        |> redirect(to: "/")

      {_, nil} ->
        redirect(conn, to: "/#{journal_path}/management/settings/context")

      {journal, %{template: template, title: title}} ->
        conn
        |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
        |> render(template,
          journal: journal,
          journal_path: journal_path,
          section: section,
          page_title: "#{title} Settings - #{journal.title}"
        )
    end
  end

  def manage_issues(conn, %{"journal_path" => journal_path}) do
    journal = find_journal_by_path(journal_path)

    if journal do
      issues = Issue.for_journal(journal.id)

      conn
      |> put_root_layout(html: {OjsLandingWeb.Layouts, :journal})
      |> render(:manage_issues,
        journal: journal,
        journal_path: journal_path,
        issues: issues,
        page_title: "Manage Issues - #{journal.title}"
      )
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  def dois(conn, %{"journal_path" => journal_path}) do
    journal = find_journal_by_path(journal_path)

    if journal do
      articles = journal.articles || []
      issues = Issue.for_journal(journal.id)

      article_items = Enum.map(articles, &article_doi_item/1)
      issue_items = Enum.map(issues, &issue_doi_item/1)
      galley_items = []

      conn
      |> put_root_layout(false)
      |> put_layout(html: {OjsLandingWeb.Layouts, :dashboard})
      |> render(:dois,
        journal: journal,
        journal_path: journal_path,
        journal_title: journal.title,
        article_items: article_items,
        issue_items: issue_items,
        galley_items: galley_items,
        status_counts: %{
          needs_doi: Enum.count(article_items, &(&1.status == :needs_doi)),
          assigned: Enum.count(article_items, &(&1.status == :assigned)),
          registered: Enum.count(article_items, &(&1.status == :registered)),
          unregistered: Enum.count(article_items, &(&1.status == :unregistered))
        },
        page_title: "DOIs - #{journal.title}"
      )
    else
      conn
      |> put_flash(:error, "Journal not found")
      |> redirect(to: "/")
    end
  end

  defp article_doi_item(article) do
    %{
      id: article.id,
      title: article[:title],
      authors: article[:authors] || [],
      pages: article[:pages],
      published_date: article[:published_date],
      doi: article[:doi],
      status: doi_status(article[:doi])
    }
  end

  defp issue_doi_item(issue) do
    %{
      id: issue.id,
      title: issue.title,
      volume: issue.volume,
      number: issue.number,
      year: issue.year,
      doi: "10.1234/informatika.v#{issue.volume || 1}i#{issue.number || 1}",
      status: :registered
    }
  end

  defp doi_status(doi) when is_binary(doi) and doi != "", do: :registered
  defp doi_status(_), do: :needs_doi

  defp find_journal_by_path(path) do
    Enum.find(Journal.all(), fn journal ->
      journal_path = journal.path || String.replace(String.downcase(journal.title), " ", "_")
      journal_path == path
    end)
  end
end
