defmodule PhoenixEmail.TailwindTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  use PhoenixEmail

  alias PhoenixEmail.Tailwind

  describe "style/1" do
    test "returns nil for nil or empty input" do
      assert Tailwind.style(nil) == nil
      assert Tailwind.style("") == nil
      assert Tailwind.style("   ") == nil
    end

    test "translates colors from the default palette" do
      assert Tailwind.style("bg-white") == "background-color:#ffffff"
      assert Tailwind.style("text-gray-500") == "color:#6b7280"
      assert Tailwind.style("border-indigo-600") == "border-color:#4f46e5"
      assert Tailwind.style("bg-transparent") == "background-color:transparent"
    end

    test "translates the spacing scale, px unit, and auto" do
      assert Tailwind.style("p-4") == "padding:16px"
      assert Tailwind.style("px-5") == "padding-left:20px;padding-right:20px"
      assert Tailwind.style("py-3") == "padding-top:12px;padding-bottom:12px"
      assert Tailwind.style("mt-2.5") == "margin-top:10px"
      assert Tailwind.style("m-px") == "margin:1px"
      assert Tailwind.style("mx-auto") == "margin-left:auto;margin-right:auto"
      assert Tailwind.style("p-0") == "padding:0px"
    end

    test "translates negative margins" do
      assert Tailwind.style("-mt-2") == "margin-top:-8px"
      assert Tailwind.style("-mx-4") == "margin-left:-16px;margin-right:-16px"
    end

    test "translates sizing with scale, keywords, and fractions" do
      assert Tailwind.style("w-full") == "width:100%"
      assert Tailwind.style("w-16") == "width:64px"
      assert Tailwind.style("w-1/2") == "width:50%"
      assert Tailwind.style("h-10") == "height:40px"
      assert Tailwind.style("max-w-full") == "max-width:100%"
    end

    test "translates typography utilities" do
      assert Tailwind.style("text-sm") == "font-size:14px;line-height:20px"
      assert Tailwind.style("text-center") == "text-align:center"
      assert Tailwind.style("font-semibold") == "font-weight:600"
      assert Tailwind.style("italic") == "font-style:italic"
      assert Tailwind.style("no-underline") == "text-decoration:none"
      assert Tailwind.style("leading-6") == "line-height:24px"
      assert Tailwind.style("leading-none") == "line-height:1"
      assert Tailwind.style("tracking-wide") == "letter-spacing:0.025em"
      assert Tailwind.style("uppercase") == "text-transform:uppercase"
      assert Tailwind.style("font-mono") =~ "font-family:ui-monospace"
    end

    test "translates borders and radius" do
      assert Tailwind.style("border") ==
               "border-width:1px;border-style:solid;border-color:#e5e7eb"

      assert Tailwind.style("border-2") == "border-width:2px;border-style:solid"
      assert Tailwind.style("border-dashed") == "border-style:dashed"
      assert Tailwind.style("rounded") == "border-radius:4px"
      assert Tailwind.style("rounded-lg") == "border-radius:8px"
      assert Tailwind.style("rounded-full") == "border-radius:9999px"
    end

    test "translates arbitrary values" do
      assert Tailwind.style("bg-[#5e6ad2]") == "background-color:#5e6ad2"
      assert Tailwind.style("text-[14px]") == "font-size:14px"
      assert Tailwind.style("text-[#333333]") == "color:#333333"
      assert Tailwind.style("p-[12px]") == "padding:12px"
      assert Tailwind.style("w-[465px]") == "width:465px"
      assert Tailwind.style("max-w-[465px]") == "max-width:465px"
      assert Tailwind.style("leading-[24px]") == "line-height:24px"
      assert Tailwind.style("font-[600]") == "font-weight:600"
    end

    test "keeps declaration order so later classes win by cascade" do
      assert Tailwind.style("p-4 bg-white text-sm") ==
               "padding:16px;background-color:#ffffff;font-size:14px;line-height:20px"
    end

    test "skips unknown classes with a warning" do
      log =
        capture_log(fn ->
          assert Tailwind.style("sm:flex bg-white hover:underline") ==
                   "background-color:#ffffff"
        end)

      assert log =~ "unknown tailwind class"
      assert log =~ "sm:flex"
    end
  end

  describe "class attribute on components" do
    defp render(rendered), do: PhoenixEmail.render(rendered)

    test "text merges defaults, tailwind classes, and style, in that order" do
      assigns = %{}

      html =
        render(~H|<.text class="text-base text-gray-500" style="color:#111111">hi</.text>|)

      assert html =~
               ~s(style="font-size:14px;line-height:24px;margin:16px 0;) <>
                 ~s(font-size:16px;line-height:24px;color:#6b7280;color:#111111")
    end

    test "button parses padding from tailwind classes for the MSO hack" do
      assigns = %{}

      html =
        render(
          ~H|<.button href="https://example.com" class="bg-black px-5 py-3 rounded">Go</.button>|
        )

      assert html =~ "background-color:#000000"
      assert html =~ "border-radius:4px"
      assert html =~ "padding:12px 20px 12px 20px"
      assert html =~ ~s(mso-font-width:100%;mso-text-raise:18)
    end

    test "container accepts tailwind classes" do
      assigns = %{}
      html = render(~H|<.container class="border border-gray-200 rounded-lg p-5">hi</.container>|)

      assert html =~ "max-width:37.5em;border-width:1px;border-style:solid;border-color:#e5e7eb;"
      assert html =~ "border-color:#e5e7eb;border-radius:8px;padding:20px"
    end

    test "column without class or style renders without a style attribute" do
      assigns = %{}
      html = render(~H|<.row>
  <.column>hi</.column>
</.row>|)

      assert html =~ "<td>hi</td>"
    end
  end
end
