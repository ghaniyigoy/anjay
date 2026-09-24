defmodule OjsLandingWeb.ReviewerControllerTest do
  use OjsLandingWeb.ConnCase

  describe "review page authentication" do
    test "GET /review/:id redirects to login when not authenticated" do
      conn = get(build_conn(), "/review/1")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "login"
    end

    test "workflow POST actions redirect to login when not authenticated" do
      for path <- [
            "/review/1/advance",
            "/review/1/copyedit/initial",
            "/review/1/galley",
            "/review/1/proofread/author",
            "/review/1/publish"
          ] do
        conn =
          build_conn()
          |> post(path, %{"_csrf_token" => Plug.CSRFProtection.get_csrf_token()})

        assert redirected_to(conn) == "/login"
      end
    end
  end

  describe "review page" do
    setup %{conn: conn} do
      OjsLanding.ReviewerAssignment.reset()
      {:ok, conn: init_test_session(conn, current_user: "reviewer")}
    end

    test "GET /review/1 shows the review wizard Guidelines step", %{conn: conn} do
      conn = get(conn, "/review/1")
      html = html_response(conn, 200)

      assert html =~ "Review: Implementasi Machine Learning"
      assert html =~ "Review Guidelines"
      assert html =~ "Continue to Step #3"
      refute html =~ "Request for Review"
    end

    test "GET /review/4 shows the Guidelines step after accepting", %{conn: conn} do
      conn = get(conn, "/review/4")
      html = html_response(conn, 200)

      assert html =~ "Request for Review"
      assert html =~ "Accept Review, Continue"
      assert OjsLanding.ReviewerAssignment.get(4).status == :action_required

      OjsLanding.ReviewerAssignment.accept_assignment(4)

      conn = get(conn, "/review/4")
      html = html_response(conn, 200)

      assert html =~ "Review Guidelines"
      assert html =~ "Continue to Step #3"
      refute html =~ "Recommendation"
    end

    test "POST /review/:id/step advances through Guidelines and Download steps", %{conn: conn} do
      conn =
        post(conn, "/review/1/step", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token()
        })

      assert redirected_to(conn) == "/review/1"
      assert OjsLanding.ReviewerAssignment.get(1).wizard_step == 3

      conn = get(conn, "/review/1")
      html = html_response(conn, 200)

      assert html =~ "Review Files"
      assert html =~ "Submit Review"
      assert html =~ "Recommendation"

      conn =
        post(conn, "/review/1/step", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token()
        })

      assert OjsLanding.ReviewerAssignment.get(1).wizard_step == 4

      conn = get(conn, "/review/1")
      html = html_response(conn, 200)

      assert html =~ "Completion"
      assert html =~ "Recommendation"
      assert html =~ "Accept Submission"
      assert html =~ "Revisions Required"
      assert html =~ "Resubmit for Review"
      assert html =~ "Decline Submission"
      assert html =~ "Submit Review"
      assert html =~ "comments_author"
    end

    test "POST /review/:id/go-back returns to the Request step from Guidelines", %{conn: conn} do
      assert OjsLanding.ReviewerAssignment.get(1).wizard_step == 2

      conn =
        post(conn, "/review/1/go-back", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token()
        })

      assert redirected_to(conn) == "/review/1"
      assert OjsLanding.ReviewerAssignment.get(1).wizard_step == 1

      conn = get(conn, "/review/1")
      html = html_response(conn, 200)

      assert html =~ "Request for Review"
      assert html =~ "Continue to Step #2"
      refute html =~ "Review Guidelines"
      assert length(Regex.scan(~r/class="rr-step active"/, html)) == 1
    end

    test "POST /review/:id/step from the Request step returns to Guidelines", %{conn: conn} do
      OjsLanding.ReviewerAssignment.go_back_review_step(1)
      assert OjsLanding.ReviewerAssignment.get(1).wizard_step == 1

      conn =
        post(conn, "/review/1/step", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token()
        })

      assert redirected_to(conn) == "/review/1"
      assert OjsLanding.ReviewerAssignment.get(1).wizard_step == 2

      conn = get(conn, "/review/1")
      html = html_response(conn, 200)

      assert html =~ "Review Guidelines"
      assert html =~ "Go Back"
    end

    test "POST /review/:id/go-back returns to Guidelines from Download & Review", %{conn: conn} do
      OjsLanding.ReviewerAssignment.advance_review_step(1)
      assert OjsLanding.ReviewerAssignment.get(1).wizard_step == 3

      conn =
        post(conn, "/review/1/go-back", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token()
        })

      assert redirected_to(conn) == "/review/1"
      assert OjsLanding.ReviewerAssignment.get(1).wizard_step == 2

      conn = get(conn, "/review/1")
      html = html_response(conn, 200)

      assert html =~ "Review Guidelines"
    end

    test "POST /review/:id/step is rejected before the assignment is accepted", %{conn: conn} do
      conn =
        post(conn, "/review/4/step", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token()
        })

      assert redirected_to(conn) == "/review/4"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "cannot be advanced"
      assert OjsLanding.ReviewerAssignment.get(4).status == :action_required
    end

    test "GET /review/9999 redirects to assignments when not found", %{conn: conn} do
      conn = get(conn, "/review/9999")

      assert redirected_to(conn) == "/dashboard/reviewAssignments"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not found"
    end

    test "POST /review/:id submits a review" do
      conn =
        post(build_conn() |> init_test_session(current_user: "reviewer"), "/review/1", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "recommendation" => "Minor Revisions",
          "comments_author" => "Solid work, minor fixes needed.",
          "comments_editor" => "Reviewer 1 sees only minor issues."
        })

      assert redirected_to(conn) == "/review/1"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Review submitted"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Minor Revisions"

      assignment = OjsLanding.ReviewerAssignment.get(1)
      assert assignment.status == :completed
      assert assignment.stage == :copyediting
      assert assignment.recommendation == "Minor Revisions"
      assert assignment.comments_author == "Solid work, minor fixes needed."
      assert length(assignment.review_history) == 1
    end

    test "GET /review/1 shows the submitted review without editor copyediting panels", %{
      conn: conn
    } do
      conn =
        post(conn, "/review/1", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "recommendation" => "Accept",
          "comments_author" => "Publishable."
        })

      assert redirected_to(conn) == "/review/1"

      conn = get(conn, "/review/1")
      html = html_response(conn, 200)

      assert html =~ "Review Submitted"
      assert html =~ "Accept"
      assert html =~ "Back to My Assignments"
      refute html =~ "Initial Copyedit"
      refute html =~ "Complete the copyediting tasks"
      refute html =~ "Proceed to Production"
      refute html =~ "Submit Review"
    end

    test "POST /review/:id/copyedit/:task marks copyediting tasks complete", %{conn: conn} do
      OjsLanding.ReviewerAssignment.submit_review(1, %{"recommendation" => "Accept"})

      for task <- ["initial", "author", "final"] do
        conn =
          post(conn, "/review/1/copyedit/#{task}", %{
            "_csrf_token" => Plug.CSRFProtection.get_csrf_token()
          })

        assert redirected_to(conn) == "/review/1"
        assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Copyediting task"
      end

      assignment = OjsLanding.ReviewerAssignment.get(1)
      assert Enum.all?(assignment.copyedit_tasks, & &1.done)
    end

    test "POST /review/:id/advance is rejected until all copyediting tasks are complete", %{
      conn: conn
    } do
      OjsLanding.ReviewerAssignment.submit_review(1, %{"recommendation" => "Accept"})

      conn =
        post(conn, "/review/1/advance", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token()
        })

      assert redirected_to(conn) == "/review/1"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "copyediting tasks"
      assert OjsLanding.ReviewerAssignment.get(1).stage == :copyediting
    end

    test "POST /review/:id/advance moves to production after copyediting completes", %{conn: conn} do
      OjsLanding.ReviewerAssignment.submit_review(1, %{"recommendation" => "Accept"})

      for task <- ["initial", "author", "final"] do
        OjsLanding.ReviewerAssignment.complete_copyedit_task(1, task)
      end

      conn =
        post(conn, "/review/1/advance", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token()
        })

      assert redirected_to(conn) == "/review/1"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Production"

      assignment = OjsLanding.ReviewerAssignment.get(1)
      assert assignment.stage == :production
      assert assignment.status == :completed
    end

    test "GET /review/1 does not show the editor production panel", %{conn: conn} do
      OjsLanding.ReviewerAssignment.submit_review(1, %{"recommendation" => "Accept"})

      for task <- ["initial", "author", "final"] do
        OjsLanding.ReviewerAssignment.complete_copyedit_task(1, task)
      end

      OjsLanding.ReviewerAssignment.set_stage(1, :production)

      conn = get(conn, "/review/1")
      html = html_response(conn, 200)

      assert html =~ "Review Submitted"
      assert html =~ "Back to My Assignments"
      refute html =~ "Galley Files"
      refute html =~ "Add Galley"
      refute html =~ "Proofreading"
      refute html =~ "No galley files yet"
      refute html =~ "Publish Submission"
    end

    test "POST /review/:id/galley adds a galley file", %{conn: conn} do
      OjsLanding.ReviewerAssignment.submit_review(1, %{"recommendation" => "Accept"})
      OjsLanding.ReviewerAssignment.set_stage(1, :production)

      conn =
        post(conn, "/review/1/galley", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "name" => "galley-pdf.pdf",
          "type" => "PDF"
        })

      assert redirected_to(conn) == "/review/1"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Galley file added"

      assignment = OjsLanding.ReviewerAssignment.get(1)
      assert [galley] = assignment.galley_files
      assert galley.name == "galley-pdf.pdf"
      assert galley.type == "PDF"
    end

    test "POST /review/:id/proofread/:task marks proofreading tasks complete", %{conn: conn} do
      OjsLanding.ReviewerAssignment.submit_review(1, %{"recommendation" => "Accept"})
      OjsLanding.ReviewerAssignment.set_stage(1, :production)

      for task <- ["author", "proofreader"] do
        conn =
          post(conn, "/review/1/proofread/#{task}", %{
            "_csrf_token" => Plug.CSRFProtection.get_csrf_token()
          })

        assert redirected_to(conn) == "/review/1"
        assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Proofreading task"
      end

      assignment = OjsLanding.ReviewerAssignment.get(1)
      assert Enum.all?(assignment.proofread_tasks, & &1.done)
    end

    test "POST /review/:id/publish is rejected until proofreading is complete", %{conn: conn} do
      OjsLanding.ReviewerAssignment.submit_review(1, %{"recommendation" => "Accept"})
      OjsLanding.ReviewerAssignment.set_stage(1, :production)

      conn =
        post(conn, "/review/1/publish", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "issue" => "Vol. 1 No. 1"
        })

      assert redirected_to(conn) == "/review/1"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "proofreading tasks"
      assert OjsLanding.ReviewerAssignment.get(1).status == :completed
    end

    test "POST /review/:id/publish publishes the submission", %{conn: conn} do
      OjsLanding.ReviewerAssignment.submit_review(1, %{"recommendation" => "Accept"})
      OjsLanding.ReviewerAssignment.set_stage(1, :production)

      for task <- ["author", "proofreader"] do
        OjsLanding.ReviewerAssignment.complete_proofread_task(1, task)
      end

      conn =
        post(conn, "/review/1/publish", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "issue" => "Vol. 1 No. 2"
        })

      assert redirected_to(conn) == "/review/1"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "published"

      assignment = OjsLanding.ReviewerAssignment.get(1)
      assert assignment.status == :published
      assert assignment.issue == "Vol. 1 No. 2"
      assert assignment.published_at
    end

    test "GET /review/1 shows the published panel", %{conn: conn} do
      OjsLanding.ReviewerAssignment.submit_review(1, %{"recommendation" => "Accept"})
      OjsLanding.ReviewerAssignment.set_stage(1, :production)
      OjsLanding.ReviewerAssignment.publish(1, %{"issue" => "Vol. 1 No. 2"})

      conn = get(conn, "/review/1")
      html = html_response(conn, 200)

      assert html =~ "Published"
      assert html =~ "Vol. 1 No. 2"
      assert html =~ "published to the journal"
      refute html =~ "Submit Review"
      refute html =~ "Add Galley"
    end
  end
end
