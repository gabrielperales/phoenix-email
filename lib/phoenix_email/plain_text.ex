defmodule PhoenixEmail.PlainText do
  @moduledoc false
  # Naive HTML → plain text conversion for the text/plain part of multipart
  # emails. Emails rendered by PhoenixEmail.Components are simple, well-formed
  # HTML, so a tag-oriented pass is enough — no full parser needed.

  @skip_element ~r/<([a-zA-Z0-9]+)[^>]*\bdata-skip-in-text\b[^>]*>(?:(?!<\1[\s>]).)*?<\/\1>/s
  @link ~r/<a\s[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/si

  def convert(html) do
    html
    |> String.replace(~r/<!DOCTYPE[^>]*>/i, "")
    |> String.replace(~r/<head[\s>].*?<\/head>/si, "")
    |> String.replace(~r/<style[\s>].*?<\/style>/si, "")
    |> strip_skipped()
    |> String.replace(~r/<!--.*?-->/s, "")
    |> String.replace(~r/<br\s*\/?>/i, "\n")
    |> String.replace(~r/<hr[^>]*>/i, "\n--------------------------------------------------\n")
    |> replace_links()
    |> String.replace(~r/<\/(?:p|div|td|tr|table|h1|h2|h3|h4|h5|h6|li|ul|ol)>/i, "\n")
    |> String.replace(~r/<[^>]+>/, "")
    |> decode_entities()
    |> normalize_whitespace()
  end

  # Removes innermost skip-marked elements first, then loops so skip-marked
  # ancestors (like the preview div wrapping its whitespace div) go too.
  defp strip_skipped(html) do
    case Regex.replace(@skip_element, html, "") do
      ^html -> html
      stripped -> strip_skipped(stripped)
    end
  end

  defp replace_links(html) do
    Regex.replace(@link, html, fn _match, url, inner ->
      label =
        inner
        |> String.replace(~r/<[^>]+>/, "")
        |> String.replace(~r/\s+/, " ")
        |> String.trim()

      cond do
        label == "" -> url
        label == url -> url
        true -> "#{label} [#{url}]"
      end
    end)
  end

  defp decode_entities(text) do
    text
    |> String.replace("&nbsp;", " ")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> String.replace("&quot;", "\"")
    |> String.replace("&#39;", "'")
    |> String.replace(~r/&#(\d+);/, fn match ->
      [_, code] = Regex.run(~r/&#(\d+);/, match)
      <<String.to_integer(code)::utf8>>
    end)
    |> String.replace("&amp;", "&")
  end

  defp normalize_whitespace(text) do
    text
    |> String.replace("\u200C", "")
    |> String.replace("\u200B", "")
    |> String.replace("\u200A", "")
    |> String.replace("\u00A0", " ")
    |> String.split("\n")
    |> Enum.map_join("\n", fn line ->
      line
      |> String.replace(~r/[ \t]+/, " ")
      |> String.trim()
    end)
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end
end
