defmodule OjsLandingWeb.DashboardHTML do
  use OjsLandingWeb, :html
  embed_templates "dashboard_html/*"

  def role_class(:author), do: "author"
  def role_class(:reviewer), do: "reviewer"
  def role_class(:editor), do: "editor"
  def role_class(:admin), do: "admin"
  def role_class(_), do: ""

  def format_role(:author), do: "Author"
  def format_role(:reviewer), do: "Reviewer"
  def format_role(:editor), do: "Editor"
  def format_role(:admin), do: "Administrator"
  def format_role(role), do: to_string(role)
end
