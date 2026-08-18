defmodule OjsLanding.User do
  @moduledoc """
  User management module backed by the existing OJS PostgreSQL database.

  Reads (and for registration, inserts into) the OJS `users`,
  `user_settings`, `user_groups` and `user_user_groups` tables without
  altering their structure.
  """

  alias OjsLanding.OJS.User, as: OJSUser
  alias OjsLanding.OJS.{UserGroup, UserSetting, UserUserGroup}
  alias OjsLanding.Repo

  import Ecto.Query

  defstruct [
    :id,
    :username,
    :password,
    :email,
    :given_name,
    :family_name,
    :affiliation,
    :country,
    :disabled,
    roles: []
  ]

  # OJS role_id constants -> application role atoms.
  @role_map %{
    1 => :admin,
    16 => :editor,
    17 => :editor,
    4096 => :reviewer,
    4097 => :assistant,
    65536 => :author,
    1_048_576 => :reader,
    2_097_152 => :subscription_manager
  }

  # Highest-priority role used for dashboard redirects / badges.
  @role_priority [:admin, :editor, :reviewer, :author]

  @doc """
  Get all users (ordered by user id)
  """
  def all do
    OJSUser
    |> order_by(:user_id)
    |> Repo.all()
    |> Enum.map(&build_user/1)
  end

  @doc """
  Find user by username
  """
  def find_by_username(username) when is_binary(username) do
    build_user(Repo.get_by(OJSUser, username: username))
  end

  @doc """
  Find user by email
  """
  def find_by_email(email) when is_binary(email) do
    build_user(Repo.get_by(OJSUser, email: email))
  end

  @doc """
  Find user by primary key
  """
  def find_by_id(user_id) do
    build_user(Repo.get(OJSUser, user_id))
  end

  @doc """
  Verify login credentials against the OJS bcrypt hash.
  """
  def verify_login(username_or_email, password) do
    user = find_by_username(username_or_email) || find_by_email(username_or_email)

    cond do
      is_nil(user) ->
        {:error, "Username atau email tidak ditemukan"}

      user.disabled == 1 ->
        {:error, "Akun dinonaktifkan. Hubungi administrator."}

      not Bcryptrs.verify_pass(password, user.password) ->
        {:error, "Password salah"}

      true ->
        {:ok, user}
    end
  end

  @doc """
  Register new user as author and persist into the OJS tables.
  """
  def register(params) do
    username = params["username"]
    email = params["email"] || ""

    if find_by_username(username) || find_by_email(email) do
      {:error, "Username atau email sudah digunakan"}
    else
      case create_user(params) do
        {:ok, user_id} -> {:ok, find_by_id(user_id)}
        {:error, _reason} -> {:error, "Gagal menyimpan data pengguna"}
      end
    end
  end

  @doc """
  Does the user have the given role atom?
  """
  def has_role?(%__MODULE__{roles: roles}, role), do: role in roles

  @doc """
  Returns the highest-priority role of the user (defaults to :reader).
  """
  def primary_role(%__MODULE__{roles: roles}) do
    case Enum.find(@role_priority, &(&1 in roles)) do
      nil -> :reader
      role -> role
    end
  end

  defp build_user(nil), do: nil

  defp build_user(%OJSUser{} = user) do
    settings = load_settings(user.user_id)

    %__MODULE__{
      id: user.user_id,
      username: user.username,
      password: user.password,
      email: user.email,
      given_name: settings["givenName"] || user.username,
      family_name: settings["familyName"] || "",
      affiliation: settings["affiliation"] || "",
      country: user.country,
      disabled: user.disabled,
      roles: load_roles(user.user_id)
    }
  end

  defp load_settings(user_id) do
    UserSetting
    |> where([us], us.user_id == ^user_id)
    |> select([us], {us.setting_name, us.setting_value})
    |> Repo.all()
    |> Enum.reduce(%{}, fn {name, value}, acc -> Map.put(acc, name, value) end)
  end

  defp load_roles(user_id) do
    from(uug in UserUserGroup,
      join: ug in UserGroup,
      on: uug.user_group_id == ug.user_group_id,
      where: uug.user_id == ^user_id,
      select: ug.role_id
    )
    |> Repo.all()
    |> Enum.map(&Map.get(@role_map, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
  end

  defp create_user(params) do
    locale = params["locale"] || "id"
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    Repo.transaction(fn ->
      user_id = next_id(OJSUser, :user_id)
      author_group = get_or_create_author_group()

      Repo.insert!(%OJSUser{
        user_id: user_id,
        username: params["username"],
        password: Bcryptrs.hash_pwd_salt(params["password"]),
        email: params["email"] || "",
        country: params["country"] || "Indonesia",
        locales: locale,
        date_registered: now,
        must_change_password: 0,
        disabled: 0,
        inline_help: 0
      })

      insert_setting(user_id, locale, "givenName", params["given_name"] || params["username"])
      insert_setting(user_id, locale, "familyName", params["family_name"] || "")
      insert_setting(user_id, locale, "affiliation", params["affiliation"] || "")

      Repo.insert!(%UserUserGroup{
        user_user_group_id: next_id(UserUserGroup, :user_user_group_id),
        user_group_id: author_group.user_group_id,
        user_id: user_id,
        date_start: now
      })

      user_id
    end)
  end

  defp insert_setting(user_id, locale, name, value) do
    Repo.insert!(%UserSetting{
      user_setting_id: next_id(UserSetting, :user_setting_id),
      user_id: user_id,
      locale: locale,
      setting_name: name,
      setting_value: value
    })
  end

  defp get_or_create_author_group do
    case Repo.one(from(g in UserGroup, where: g.role_id == ^65536, limit: 1)) do
      nil ->
        group = %UserGroup{
          user_group_id: next_id(UserGroup, :user_group_id),
          context_id: nil,
          role_id: 65536,
          is_default: 1,
          show_title: 1,
          permit_self_registration: 1,
          permit_metadata_edit: 1,
          permit_settings: 0,
          masthead: 0
        }

        Repo.insert!(group)

      group ->
        group
    end
  end

  defp next_id(queryable, field) do
    case Repo.aggregate(queryable, :max, field) do
      nil -> 1
      max -> max + 1
    end
  end
end
