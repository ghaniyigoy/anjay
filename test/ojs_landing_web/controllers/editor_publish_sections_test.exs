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
    assert html =~ "Accept and Skip Review"
    assert html =~ "Decline Submission"
    assert html =~ "submission-action-panel"
    assert html =~ "submission-actions"
    assert html =~ "sendToReviewModal"
    assert html =~ "skipReviewModal"
    assert html =~ "declineModal"
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

  test "schedule for publication modal renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/issue")
    html = html_response(conn, 200)

    assert html =~ "scheduleModal"
    assert html =~ "Vol. 1, No. 1"
    assert html =~ "Send a notification to all participants"
  end

  test "production page schedule button is wired to modal", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/production")
    html = html_response(conn, 200)

    assert html =~ "openModal('scheduleModal')"
    assert html =~ "Schedule For Publication"
  end

  test "unknown section falls back to submission workflow", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1/foo")
    assert html_response(conn, 200) =~ "Submission"
  end

  test "activity log & notes modal renders", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1")
    html = html_response(conn, 200)

    assert html =~ "activityModal"
    assert html =~ "Activity Log"
    assert html =~ "Submission created"
    assert html =~ "Email notification sent"
    assert html =~ "Waiting for the author to address reviewer comments"
    assert html =~ "Add Entry"
    assert html =~ "Add Note"
  end

  test "notes empty state renders for submission without notes", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/2")
    html = html_response(conn, 200)

    assert html =~ "No notes available."
  end

  test "submission library modal renders categories", %{conn: conn} do
    conn = get(conn, "/dashboard/editorial/submissions/1")
    html = html_response(conn, 200)

    assert html =~ "libraryModal"
    assert html =~ "Submission Library"
    assert html =~ "Add File"
    assert html =~ "Document Library"
    assert html =~ "Marketing"
    assert html =~ "Permissions"
    assert html =~ "Reports"
    assert html =~ "Other"
    assert html =~ "Upload File"
  end
end
