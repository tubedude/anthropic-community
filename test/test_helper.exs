Mox.defmock(Anthropic.MockHTTPClient, for: Anthropic.HTTPClient)
Application.put_env(:anthropic, :http_client, Anthropic.MockHTTPClient)

for file <- File.ls!("test/support") do
  Code.require_file("test/support/#{file}")
end

ExUnit.start()
