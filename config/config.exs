import Config

# Only relevant when working on phoenix_email itself: swoosh is an optional
# dependency used in tests, and without an HTTP client configured its
# application fails to start.
if Mix.env() in [:dev, :test] do
  config :swoosh, api_client: false
end
