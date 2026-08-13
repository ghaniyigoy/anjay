defmodule OjsLandingWeb.ReviewerControllerTest do
  use OjsLandingWeb.ConnCase

  describe "review page authentication" do
    test "GET /review/:id redirects to login when not authenticated" do
      conn = get(build_conn(), "/review/1")

      assert redirected_to(conn) == "/login"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "login"
    end
  end

  describe "review page" do
    setup %{conn: conn} do
      {:ok, conn: init_test_session(conn, current_user: "reviewer")}
    end

    test "GET /review/1 renders the review workflow", %{conn: conn} do
      conn = get(conn, "/review/1")
      html = html_response(conn, 200)

      assert html =~ "Submission Review"
      assert html =~ "Implementasi Machine Learning"
      assert html =~ "Recommendation"
      assert html =~ "comments_author"
      assert html =~ "Review Files"
    end

    test "GET /review/9999 redirects to assignments when not found", %{conn: conn} do
      conn = get(conn, "/review/9999")

      assert redirected_to(conn) == "/dashboard/reviewAssignments"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "not found"
    end

    test "POST /review/:id submits a review", %{conn: conn} do
      conn =
        post(conn, "/review/1", %{
          "_csrf_token" => Plug.CSRFProtection.get_csrf_token(),
          "recommendation" => "Minor Revisions",
          "comments_author" => "Solid work, minor fixes needed.",
          "comments_editor" => "Reviewer 1 sees only minor issues."
        })

      assert redirected_to(conn) == "/review/1"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Review submitted"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Minor Revisions"
    end
  end
end
