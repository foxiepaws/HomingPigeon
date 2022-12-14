defmodule HomingPigeon.Formatter do
  @moduledoc """
  Transforms messages to/from discord from/to irc
  """
  alias HomingPigeon.DiscordInfo

  @discordcdn "https://cdn.discordapp.com/"

  def from_irc(_nick, msg, ctcp \\ false) do
    # strip or replace IRC formatting.
    fmsg =
      msg
      |> :re.replace("\x02(.*?)\x02", "**\\g1**", [:global])
      |> :re.replace("\x02(.*)", "**\\g1**")
      |> :re.replace("\x01|\x03[0123456789]*(,[0123456789]*)?", "", [:global])

    case ctcp do
      true ->
        case fmsg do
          x when is_binary(x) -> "_#{x}_"
          x when is_list(x) -> "_#{List.to_string(x)}_"
        end

      false ->
        case fmsg do
          x when is_binary(x) -> "#{x}"
          x when is_list(x) -> "#{List.to_string(x)}"
        end
    end
  end

  def get_id_info([match, type, id], guild) do
    i = String.to_integer(id)

    case type do
      "#" ->
        {match, "#" <> DiscordInfo.get_channel_name_by_id(i)}

      "@" ->
        {match, "@" <> DiscordInfo.get_nick_by_id(guild, i)}

      "@!" ->
        {match, "@" <> DiscordInfo.get_nick_by_id(guild, i)}

      "@&" ->
        {match, "@" <> DiscordInfo.get_role_name_by_id(guild, i)}
    end
  end

  def do_replace(str, [head | tail]) do
    {fst, snd} = head
    do_replace(String.replace(str, fst, snd, global: true), tail)
  end

  def do_replace(str, []) do
    str
  end

  def fixdiscordidstrings(%{:content => content, :guild_id => guild}) do
    pattern = ~r/\<(\@[!&]?|#)(\d+)\>/um

    matches =
      Regex.scan(pattern, content)
      |> Enum.uniq()
      |> Enum.map(&get_id_info(&1, guild))

    content
    |> do_replace(matches)
  end

  def from_discord(
        %{attachments: attachments, author: user, guild_id: guild, sticker_items: nil} = msg
      ) do
    usr = DiscordInfo.get_nick_by_id(guild, user.id)

    cpart =
      msg
      |> fixdiscordidstrings
      |> String.split("\n")

    apart =
      attachments
      |> Enum.map(& &1.url)

    messages =
      (cpart ++ apart)
      |> Enum.filter(&(&1 != ""))

    # discord may give... many lines. split and format.
    case Enum.count(messages) do
      0 ->
        {:error, "empty set"}

      _ ->
        {:ok, usr,
         messages
         |> Enum.map(fn m -> "#{m}" end)}
    end
  end

  def from_discord(
        %{attachments: attachments, author: user, guild_id: guild, sticker_items: stickers} = msg
      ) do
    usr = DiscordInfo.get_nick_by_id(guild, user.id)

    cpart =
      msg
      |> fixdiscordidstrings
      |> String.split("\n")

    apart =
      attachments
      |> Enum.map(& &1.url)

    spart =
      stickers
      |> Enum.map(fn s -> "#{@discordcdn}stickers/#{s.id}.png" end)

    messages =
      (cpart ++ apart ++ spart)
      |> Enum.filter(&(&1 != ""))

    # discord may give... many lines. split and format.
    case Enum.count(messages) do
      0 ->
        {:error, "empty set"}

      _ ->
        {:ok, usr,
         messages
         |> Enum.map(fn m -> "#{m}" end)}
    end
  end
end
