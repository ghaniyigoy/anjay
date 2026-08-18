defmodule OjsLanding.OJS.UserGroup do
  @moduledoc """
  Ecto schema mapping to the existing OJS `user_groups` table (read-only by contract).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:user_group_id, :integer, autogenerate: false}
  schema "user_groups" do
    field(:context_id, :integer)
    field(:role_id, :integer)
    field(:is_default, :integer)
    field(:show_title, :integer)
    field(:permit_self_registration, :integer)
    field(:permit_metadata_edit, :integer)
    field(:permit_settings, :integer)
    field(:masthead, :integer)

    has_many(:user_user_groups, OjsLanding.OJS.UserUserGroup,
      foreign_key: :user_group_id,
      references: :user_group_id
    )
  end

  def changeset(user_group, attrs) do
    user_group
    |> cast(attrs, [
      :user_group_id,
      :context_id,
      :role_id,
      :is_default,
      :show_title,
      :permit_self_registration,
      :permit_metadata_edit,
      :permit_settings,
      :masthead
    ])
    |> validate_required([:user_group_id, :role_id])
  end
end
