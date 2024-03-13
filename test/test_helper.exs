ExUnit.start()

for file <- File.ls!("test/support") do
  Code.require_file("test/support/#{file}")
end
