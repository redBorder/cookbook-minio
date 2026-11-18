minio_config 'config' do
  # before the data bags exist
  openbao node['redborder'] && node['redborder']['openbao_secrets'] == true
  action [:add]
end
