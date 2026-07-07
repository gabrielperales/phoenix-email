defmodule PhoenixEmail.TailwindTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  use PhoenixEmail

  alias PhoenixEmail.Tailwind
  alias PhoenixEmail.Tailwind.Compiler

  @map %{
    "bg-black" => "background-color:#000000",
    "text-white" => "color:#ffffff",
    "text-sm" => "font-size:14px;line-height:20px",
    "px-5" => "padding-left:20px;padding-right:20px",
    "py-3" => "padding-top:12px;padding-bottom:12px",
    "rounded" => "border-radius:4px",
    "max-w-[465px]" => "max-width:465px",
    "text-gray-500" => "color:#6b7280"
  }

  setup do
    Tailwind.put_map(@map)
    on_exit(fn -> Tailwind.put_map(%{}) end)
  end

  describe "style/1" do
    test "returns nil for nil or empty input" do
      assert Tailwind.style(nil) == nil
      assert Tailwind.style("") == nil
      assert Tailwind.style("   ") == nil
    end

    test "joins the compiled declarations in class order" do
      assert Tailwind.style("bg-black px-5") ==
               "background-color:#000000;padding-left:20px;padding-right:20px"

      assert Tailwind.style("max-w-[465px]") == "max-width:465px"
    end

    test "skips classes missing from the compiled map with a warning" do
      log =
        capture_log(fn ->
          assert Tailwind.style("bg-black nope-42") == "background-color:#000000"
        end)

      assert log =~ "nope-42"
      assert log =~ "mix phoenix_email.tailwind"
    end
  end

  describe "class attribute on components" do
    defp render(rendered), do: PhoenixEmail.render(rendered)

    test "text merges defaults, compiled classes, and style, in that order" do
      assigns = %{}

      html = render(~H|<.text class="text-sm text-gray-500" style="color:#111111">hi</.text>|)

      assert html =~
               ~s(style="font-size:14px;line-height:24px;margin:16px 0;) <>
                 ~s(font-size:14px;line-height:20px;color:#6b7280;color:#111111")
    end

    test "button parses padding from compiled classes for the MSO hack" do
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

    test "container accepts compiled classes" do
      assigns = %{}
      html = render(~H|<.container class="max-w-[465px]">hi</.container>|)

      assert html =~ ~s(style="max-width:37.5em;max-width:465px")
    end

    test "column without class or style renders without a style attribute" do
      assigns = %{}
      html = render(~H|<.row>
  <.column>hi</.column>
</.row>|)

      assert html =~ "<td>hi</td>"
    end
  end

  describe "Compiler.parse/2" do
    test "converts rem to px and resolves tailwind custom properties" do
      css = """
      .px-5 {
        padding-left: 1.25rem;
        padding-right: 1.25rem
      }
      .bg-black {
        --tw-bg-opacity: 1;
        background-color: rgb(0 0 0 / var(--tw-bg-opacity, 1))
      }
      """

      assert Compiler.parse(css) == %{
               "px-5" => "padding-left:20px;padding-right:20px",
               "bg-black" => "background-color:#000000"
             }
    end

    test "keeps alpha colors as rgba and unescapes arbitrary selectors" do
      css = """
      .bg-white\\/50 {
        background-color: rgb(255 255 255 / 0.5)
      }
      .max-w-\\[465px\\] {
        max-width: 465px
      }
      """

      assert Compiler.parse(css) == %{
               "bg-white/50" => "background-color:rgba(255,255,255,0.5)",
               "max-w-[465px]" => "max-width:465px"
             }
    end

    test "drops at-rule blocks, pseudo selectors, and unresolved vars" do
      css = """
      @media (min-width: 640px) {
        .sm\\:flex {
          display: flex
        }
      }
      .hover\\:underline:hover {
        text-decoration-line: underline
      }
      .ring {
        box-shadow: var(--tw-ring-inset) 0 0 0 1px var(--tw-ring-color)
      }
      .mx-auto {
        margin-left: auto;
        margin-right: auto
      }
      """

      assert Compiler.parse(css) == %{
               "mx-auto" => "margin-left:auto;margin-right:auto"
             }
    end

    test "strips comments and ignores non-class selectors" do
      css = """
      /* tailwindcss v3.4.17 */
      *, ::before, ::after {
        --tw-border-spacing-x: 0
      }
      .-mt-2 {
        margin-top: -0.5rem
      }
      """

      assert Compiler.parse(css) == %{"-mt-2" => "margin-top:-8px"}
    end
  end

  describe "end to end with the tailwindcss binary" do
    @describetag :tailwind_bin

    @tag timeout: 120_000
    test "compiles classes scanned from source files" do
      tmp = Path.join(System.tmp_dir!(), "phx_email_tw_#{System.unique_integer([:positive])}")
      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      content_file = Path.join(tmp, "emails.ex")

      File.write!(content_file, """
      # class="bg-black text-white px-5 py-3 rounded-lg max-w-[465px] sm:flex"
      """)

      {:ok, map} =
        Compiler.run(content: [content_file], output: Path.join(tmp, "tailwind.map"))

      assert map["bg-black"] == "background-color:#000000"
      assert map["px-5"] == "padding-left:20px;padding-right:20px"
      assert map["rounded-lg"] == "border-radius:8px"
      assert map["max-w-[465px]"] == "max-width:465px"
      refute Map.has_key?(map, "sm:flex")

      assert File.exists?(Path.join(tmp, "tailwind.map"))
    end
  end
end
