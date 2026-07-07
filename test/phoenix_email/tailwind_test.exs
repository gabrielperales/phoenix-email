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

  describe "Compiler.parse/2 with tailwind v4 output" do
    # Condensed from real `tailwindcss v4.3.2` output.
    @v4_css """
    /*! tailwindcss v4.3.2 | MIT License | https://tailwindcss.com */
    @layer properties;
    @layer theme, utilities;
    @layer theme {
      :root, :host {
        --color-red-500: oklch(63.7% 0.237 25.331);
        --color-black: #000;
        --color-white: #fff;
        --spacing: 0.25rem;
        --text-sm: 0.875rem;
        --text-sm--line-height: calc(1.25 / 0.875);
        --radius-lg: 0.5rem;
        --font-weight-semibold: 600;
      }
    }
    @layer utilities {
      .mx-auto {
        margin-inline: auto;
      }
      .-mt-2 {
        margin-top: calc(var(--spacing) * -2);
      }
      .w-1\\/2 {
        width: calc(1 / 2 * 100%);
      }
      .rounded-lg {
        border-radius: var(--radius-lg);
      }
      .border {
        border-style: var(--tw-border-style);
        border-width: 1px;
      }
      .bg-red-500 {
        background-color: var(--color-red-500);
      }
      .bg-white\\/50 {
        background-color: color-mix(in srgb, #fff 50%, transparent);
        @supports (color: color-mix(in lab, red, red)) {
          background-color: color-mix(in oklab, var(--color-white) 50%, transparent);
        }
      }
      .px-5 {
        padding-inline: calc(var(--spacing) * 5);
      }
      .text-sm {
        font-size: var(--text-sm);
        line-height: var(--tw-leading, var(--text-sm--line-height));
      }
      .font-semibold {
        --tw-font-weight: var(--font-weight-semibold);
        font-weight: var(--font-weight-semibold);
      }
      .hover\\:underline {
        &:hover {
          @media (hover: hover) {
            text-decoration-line: underline;
          }
        }
      }
      .sm\\:flex {
        @media (width >= 40rem) {
          display: flex;
        }
      }
    }
    @property --tw-border-style {
      syntax: "*";
      inherits: false;
      initial-value: solid;
    }
    """

    test "resolves theme variables, calc, and @property initial values" do
      map = Compiler.parse(@v4_css)

      assert map["px-5"] == "padding-left:20px;padding-right:20px"
      assert map["-mt-2"] == "margin-top:-8px"
      assert map["mx-auto"] == "margin-left:auto;margin-right:auto"
      assert map["w-1/2"] == "width:50%"
      assert map["rounded-lg"] == "border-radius:8px"
      assert map["border"] == "border-style:solid;border-width:1px"
      assert map["font-semibold"] == "font-weight:600"
    end

    test "converts oklch theme colors to hex" do
      map = Compiler.parse(@v4_css)

      # cross-checked against an independent oklch->srgb implementation
      assert map["bg-red-500"] == "background-color:#fb2c36"
    end

    test "converts color-mix with transparent to rgba and drops the @supports variant" do
      map = Compiler.parse(@v4_css)

      assert map["bg-white/50"] == "background-color:rgba(255,255,255,0.5)"
    end

    test "resolves nested var() defaults to an evaluated line-height" do
      map = Compiler.parse(@v4_css)

      assert map["text-sm"] == "font-size:14px;line-height:1.4286"
    end

    test "still skips variants" do
      map = Compiler.parse(@v4_css)

      refute Map.has_key?(map, "sm:flex")
      refute Map.has_key?(map, "hover:underline")
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

    @tag timeout: 120_000
    test "compiles with a v4 standalone binary when TAILWIND_V4_BIN is set" do
      case System.get_env("TAILWIND_V4_BIN") do
        nil ->
          :ok

        bin ->
          previous = Application.get_env(:phoenix_email, :tailwind_bin)
          Application.put_env(:phoenix_email, :tailwind_bin, bin)

          on_exit(fn ->
            case previous do
              nil -> Application.delete_env(:phoenix_email, :tailwind_bin)
              value -> Application.put_env(:phoenix_email, :tailwind_bin, value)
            end
          end)

          tmp =
            Path.join(System.tmp_dir!(), "phx_email_tw4_#{System.unique_integer([:positive])}")

          File.mkdir_p!(tmp)
          on_exit(fn -> File.rm_rf!(tmp) end)

          content_file = Path.join(tmp, "emails.ex")

          File.write!(content_file, """
          # class="bg-red-500 text-white px-5 py-3 rounded-lg max-w-[465px] w-1/2 sm:flex"
          """)

          {:ok, map} =
            Compiler.run(content: [content_file], output: Path.join(tmp, "tailwind.map"))

          assert map["bg-red-500"] == "background-color:#fb2c36"
          assert map["px-5"] == "padding-left:20px;padding-right:20px"
          assert map["py-3"] == "padding-top:12px;padding-bottom:12px"
          assert map["rounded-lg"] == "border-radius:8px"
          assert map["max-w-[465px]"] == "max-width:465px"
          assert map["w-1/2"] == "width:50%"
          refute Map.has_key?(map, "sm:flex")
      end
    end
  end
end
