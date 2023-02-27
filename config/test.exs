import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ships, ShipsWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "mPj6q4J6r5V/bfGu9ntzucvpfBiP5+TC17WDe/FQ0CR85TDGEEcAPM8UCQB9kVV+",
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
