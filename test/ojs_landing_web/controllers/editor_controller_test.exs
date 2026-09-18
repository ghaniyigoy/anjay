defmodule OjsLandingWeb.EditorControllerTest do
  use OjsLandingWeb.ConnCase

  alias OjsLanding.Submission

  describe "editorial dashboard" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "editor")}
    end

    test "GET /dashboard/editorial renders the editorial dashboard", %{conn: conn} do
      conn = get(conn, "/dashboard/editorial")

      assert html_response(conn, 200) =~ "Editor Dashboard"
    end

    test "shows the contributor name from the submission, not the account name", %{conn: conn} do
      submission = Submission.create("author1", "Naskah Nama Kontributor")

      {:ok, _} =
        Submission.update(submission.id, %{
          "title" => "Naskah Nama Kontributor",
          "contributors" => [
            %{
              id: 1,
              given_name: "Siti",
              family_name: "Marpuah",
              email: "siti@test.com",
              affiliation: "Universitas Contoh",
              country: "Indonesia",
              role: :author,
              primary: true
            }
          ]
        })

      Submission.set_status(submission.id, :active)

      conn = get(conn, "/dashboard/editorial?currentViewId=active")
      html = html_response(conn, 200)

      assert html =~ "Naskah Nama Kontributor"
      assert html =~ "Siti Marpuah"
    end

    test "falls back to the account name when there are no contributors", %{conn: conn} do
      submission = Submission.create("author1", "Naskah Tanpa Kontributor")

      Submission.set_status(submission.id, :active)

      conn = get(conn, "/dashboard/editorial?currentViewId=active")
      html = html_response(conn, 200)

      assert html =~ "Ahmad Fauzi"
    end

    test "newly submitted submissions without an assigned editor do not appear in Assigned to me",
         %{conn: conn} do
      submission = Submission.create("author1", "Naskah Belum Diassign Editor")
      Submission.set_status(submission.id, :active)

      html = get(conn, "/dashboard/editorial?currentViewId=assigned-to-me") |> html_response(200)

      refute html =~ "Naskah Belum Diassign Editor"
    end

    test "submissions appear in Assigned to me once an editor is assigned", %{conn: conn} do
      submission = Submission.create("author1", "Naskah Sudah Diassign Editor")
      Submission.set_status(submission.id, :active)
      Submission.assign_editor(submission.id, %{"username" => "editor", "role" => "editor"})

      html = get(conn, "/dashboard/editorial?currentViewId=assigned-to-me") |> html_response(200)

      assert html =~ "Naskah Sudah Diassign Editor"
    end
  end

  describe "send to review email notification wizard" do
    setup %{conn: conn} do
      conn = init_test_session(conn, current_user: "editor")
      submission = Submission.create("author1", "Naskah Email Notification")

      {:ok, _} =
        Submission.update(submission.id, %{
          "contributors" => [
            %{
              id: 1,
              given_name: "Siti",
              family_name: "Marpuah",
              email: "siti@test.com",
              primary: true
            }
          ]
        })

      {:ok, conn: conn, submission: submission}
    end

    test "GET /dashboard/editorial/:id/send-to-review renders the Notify Authors page", %{
      conn: conn,
      submission: submission
    } do
      conn = get(conn, "/dashboard/editorial/#{submission.id}/send-to-review")

      html = html_response(conn, 200)

      assert html =~ "Send for Review"
      assert html =~ "Notify authors"
      assert html =~ "This submission is ready to be sent for peer review."
      assert html =~ "Email Templates"
      assert html =~ "Find Template"
      assert html =~ "Your submission has been sent for review"
    end

    test "Continue goes to the Select Files step", %{conn: conn, submission: submission} do
      conn =
        get(
          conn,
          "/dashboard/editorial/#{submission.id}/send-to-review/select-files"
        )

      html = html_response(conn, 200)

      assert html =~ "Select files"
      assert html =~ "Submission Files"
      assert html =~ "Send for Review"
    end

    test "POST /send-to-review still transitions the submission", %{
      conn: conn,
      submission: submission
    } do
      conn = post(conn, "/dashboard/editorial/#{submission.id}/send-to-review")

      assert redirected_to(conn) =~ "workflow_3_1"

      updated = Submission.get(submission.id)
      assert updated.stage == :external_review
      assert updated.status == :active
    end
  end

  describe "workflow_3_1 external review layout" do
    setup %{conn: conn} do
      conn = init_test_session(conn, current_user: "editor")
      submission = Submission.create("author1", "Naskah Review Round")

      {:ok, _} =
        Submission.update(submission.id, %{"title" => "Naskah Review Round"})

      Submission.set_status(submission.id, :active)
      Submission.set_stage(submission.id, :external_review)

      {:ok, conn: conn, submission: submission}
    end

    test "renders the redesigned external review panels and right-side action panel", %{
      conn: conn,
      submission: submission
    } do
      conn =
        get(
          conn,
          "/dashboard/editorial?workflowSubmissionId=#{submission.id}&currentViewId=assigned-to-me&workflowMenuKey=workflow_3_1"
        )

      html = html_response(conn, 200)

      assert html =~ "WORKFLOW: REVIEW (ROUND 1)"
      assert html =~ "Status Info"
      assert html =~ "Round 1 Status"
      assert html =~ "Waiting for reviewers to be assigned."
      assert html =~ "Revisions Uploaded"
      assert html =~ "Reviewers"
      assert html =~ "Add reviewers"
      assert html =~ "Review Discussions"
      assert html =~ "Add Discussion"
      assert html =~ "btn-request-revisions"
      assert html =~ "Request Revisions"
      assert html =~ "btn-accept-submission"
      assert html =~ "Accept Submission"
      assert html =~ "btn-decline-review"
      assert html =~ "Decline Submission"
      assert html =~ "btn-create-new-review-round"
      assert html =~ "Create New Review Round"
      assert html =~ "btn-cancel-review-round"
      assert html =~ "Cancel Review Round"
    end
  end
end
