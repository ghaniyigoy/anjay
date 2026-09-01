defmodule OjsLandingWeb.EditorPublishSectionsTest do
  use OjsLandingWeb.ConnCase

  setup %{conn: conn} do
    {:ok, conn: init_test_session(conn, current_user: "editor")}
  end

  test "submission workflow page renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1")
    html = html_response(conn, 200)

    assert html =~ "Submission"
    assert html =~ "Send to Review"
    assert html =~ "Decline Submission"
    assert html =~ "Submission Files"
    assert html =~ "Pre-Review Discussions"
    assert html =~ "Participants"
  end

  test "review workflow page renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/review")
    html = html_response(conn, 200)

    assert html =~ "Review"
    assert html =~ "Round 1"
    assert html =~ "Add Reviewer"
    assert html =~ "Round Discussions"
    assert html =~ "RECOMMENDATION"
    assert html =~ "Dr. Ratna Dewi"
  end

  test "copyediting workflow page renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/copyediting")
    html = html_response(conn, 200)

    assert html =~ "Copyediting"
    assert html =~ "Copyediting Status"
    assert html =~ "Copyediting Files"
    assert html =~ "Copyediting Discussions"
    assert html =~ "Send to Production"
  end

  test "production workflow page renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/production")
    html = html_response(conn, 200)

    assert html =~ "Production"
    assert html =~ "Production Generating Files"
    assert html =~ "Production Discussions"
    assert html =~ "Schedule For Publication"
  end

  test "title and abstract page renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/title-abstract")
    html = html_response(conn, 200)

    assert html =~ "Title &amp; Abstract"
    assert html =~ "Prefix"
    assert html =~ "Subtitle"
    assert html =~ "Abstract"
    assert html =~ "abstract-rte-content"
    assert html =~ "Superscript"
    assert html =~ "Example: A, The"
  end

  test "contributors page renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/contributors")
    html = html_response(conn, 200)

    assert html =~ "Contributors"
    assert html =~ "Ahmad Fauzi"
    assert html =~ "Add Contributor"
  end

  test "metadata page renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/metadata")
    html = html_response(conn, 200)

    assert html =~ "Metadata"
    assert html =~ "Keywords"
  end

  test "references page renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/references")
    html = html_response(conn, 200)

    assert html =~ "References"
  end

  test "jats xml page renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/jats-xml")
    html = html_response(conn, 200)

    assert html =~ "JATS XML"
    assert html =~ "Upload"
  end

  test "galley page renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/galley")
    html = html_response(conn, 200)

    assert html =~ "Galley"
    assert html =~ "No Items"
  end

  test "permissions page renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/permissions")
    html = html_response(conn, 200)

    assert html =~ "Permissions &amp; Disclosure"
    assert html =~ "Copyright Holder"
    assert html =~ "License URL"
  end

  test "issue page renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/issue")
    html = html_response(conn, 200)

    assert html =~ "Issue"
    assert html =~ "Schedule For Publication"
    assert html =~ "Cover Image"
  end

  test "unknown section falls back to submission workflow", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/foo")
    assert html_response(conn, 200) =~ "Submission"
  end
end
