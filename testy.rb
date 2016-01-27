local_certs_dir = File.dirname(ARGV.first)
bundle_file = 'certs/bundle.pem'
if File.exist?(bundle_file) then
  File.truncate(bundle_file, 0)
end

local_cert_chain = open("certs/bundle.pem", 'w')
Dir.glob("#{local_certs_dir}/*.crt") do |cert|
  data = File.read(cert)
  local_cert_chain.write(data)
end



