minio_config 'config' do
  # first install step, before the data bags exist: the flag comes from the solo attributes
  openbao node['redborder'] && node['redborder']['openbao_secrets'] == true
  action [:add]
end
