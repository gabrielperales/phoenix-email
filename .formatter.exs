# Used by "mix format"
[
  plugins: [Phoenix.LiveView.HTMLFormatter],
  inputs: ["{mix,.formatter}.exs", "{config,lib,test,examples}/**/*.{ex,exs,heex}"],
  # Emails render whitespace as-is in some clients; keep component templates
  # on one line instead of letting the formatter introduce line breaks.
  heex_line_length: 300
]
