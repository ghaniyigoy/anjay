defmodule OjsLanding.OJS.User do
  @moduledoc """
  Ecto schema mapping to the existing OJS `users` table (read-only by contract).
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:user_id, :integer, autogenerate: false}
  schema "users" do
    field(:username, :string)
    field(:password, :string)
    field(:email, :string)
    field(:url, :string)
    field(:phone, :string)
    field(:mailing_address, :string)
    field(:billing_address, :string)
    field(:country, :string)
    field(:locales, :string)
    field(:gossip, :string)
    field(:date_last_email, :naive_datetime)
    field(:date_registered, :naive_datetime)
    field(:date_validated, :naive_datetime)
    field(:date_last_login, :naive_datetime)
    field(:must_change_password, :integer)
    field(:auth_id, :integer)
    field(:auth_str, :string)
    field(:disabled, :integer)
    field(:disabled_reason, :string)
    field(:inline_help, :integer)
    field(:remember_token, :string)

    has_many(:user_user_groups, OjsLanding.OJS.UserUserGroup,
      foreign_key: :user_id,
      references: :user_id
    )
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [
      :user_id,
      :username,
      :password,
      :email,
      :country,
      :locales,
      :date_registered,
      :must_change_password,
      :disabled,
      :inline_help
    ])
    |> validate_required([:user_id, :username, :password, :email, :date_registered])
  end
end
