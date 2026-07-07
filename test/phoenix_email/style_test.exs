defmodule PhoenixEmail.StyleTest do
  use ExUnit.Case, async: true

  use PhoenixEmail

  alias PhoenixEmail.Style

  defp render(rendered) do
    PhoenixEmail.render(rendered)
  end

  describe "to_css/1" do
    test "passes strings through untouched" do
      assert Style.to_css("display:block") == "display:block"
    end

    test "returns nil for nil, empty maps, and empty lists" do
      assert Style.to_css(nil) == nil
      assert Style.to_css(%{}) == nil
      assert Style.to_css([]) == nil
    end

    test "converts a map with string keys" do
      assert Style.to_css(%{"display" => "block"}) == "display:block"
    end

    test "converts snake_case atom keys to kebab-case" do
      assert Style.to_css(%{font_size: "14px"}) == "font-size:14px"
    end

    test "converts camelCase keys to kebab-case" do
      assert Style.to_css(%{"fontSize" => "14px"}) == "font-size:14px"
      assert Style.to_css(%{backgroundColor: "#fff"}) == "background-color:#fff"
    end

    test "renders map declarations sorted by property" do
      assert Style.to_css(%{margin_top: "4px", display: "block"}) ==
               "display:block;margin-top:4px"
    end

    test "keeps keyword list order" do
      assert Style.to_css(margin_top: "4px", display: "block") ==
               "margin-top:4px;display:block"
    end

    test "appends px to numeric values" do
      assert Style.to_css(%{padding: 12}) == "padding:12px"
      assert Style.to_css(%{width: 37.5}) == "width:37.5px"
    end

    test "keeps unitless properties unitless" do
      assert Style.to_css(%{line_height: 1.5, opacity: 0, font_weight: 700}) ==
               "font-weight:700;line-height:1.5;opacity:0"
    end

    test "drops nil and false values" do
      assert Style.to_css(%{display: "block", color: nil}) == "display:block"
      assert Style.to_css(%{color: nil}) == nil
      assert Style.to_css(%{font_weight: false && 700, color: "#333"}) == "color:#333"
    end
  end

  describe "merge/2 with style objects" do
    test "merges a map over a base string" do
      assert Style.merge("display:block", %{color: "#fff"}) == "display:block;color:#fff"
    end

    test "merges two maps" do
      assert Style.merge(%{display: "block"}, %{color: "#fff"}) == "display:block;color:#fff"
    end
  end

  describe "components with style objects" do
    test "renders a map style as an inline CSS string" do
      assigns = %{}
      html = render(~H|<.text style={%{"color" => "#333", font_size: 16}}>Hi</.text>|)

      assert html =~
               ~s(style="font-size:14px;line-height:24px;margin:16px 0;color:#333;font-size:16px")
    end

    test "renders a keyword list style in order" do
      assigns = %{}

      html =
        render(~H|<.section style={[padding: 24, background_color: "#f6f8fa"]}>Hi</.section>|)

      assert html =~ ~s(style="padding:24px;background-color:#f6f8fa")
    end

    test "button parses padding from a map style" do
      assigns = %{}

      html =
        render(
          ~H|<.button href="https://example.com" style={%{padding: "12px 20px"}}>Go</.button>|
        )

      assert html =~ "padding:12px 20px 12px 20px"
      assert html =~ "mso-text-raise:18"
    end

    test "omits the style attribute for an empty map" do
      assigns = %{}
      html = render(~H|<.body style={%{}}>Hi</.body>|)

      assert html =~ "<body>"
    end
  end
end
