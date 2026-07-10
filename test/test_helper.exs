Application.put_env(:anthropic, :http_adapter, Anthropic.MockHTTPAdapter)

for file <- File.ls!("test/support") do
  Code.require_file("test/support/#{file}")
end

ExUnit.start()
