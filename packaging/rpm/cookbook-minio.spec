Name: cookbook-minio
Version: %{__version}
Release: %{__release}%{?dist}
BuildArch: noarch
Summary: Minio cookbook to install and configure it in redborder environments

License: AGPL 3.0
URL: https://github.com/redBorder/cookbook-minio
Source0: %{name}-%{version}.tar.gz

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}/var/chef/cookbooks/minio
cp -f -r  resources/* %{buildroot}/var/chef/cookbooks/minio
chmod -R 0755 %{buildroot}/var/chef/cookbooks/minio
install -D -m 0644 README.md %{buildroot}/var/chef/cookbooks/minio/README.md

%pre
if [ -d /var/chef/cookbooks/minio ]; then
    rm -rf /var/chef/cookbooks/minio
fi

%post
case "$1" in
  1)
    # This is an initial install.
    :
  ;;
  2)
    # This is an upgrade.
    su - -s /bin/bash -c 'source /etc/profile && rvm gemset use default && env knife cookbook upload minio'
    CDOMAIN_FILE="/etc/redborder/cdomain"

    if [ -f "$CDOMAIN_FILE" ]; then
      SUFFIX=$(cat "$CDOMAIN_FILE")
    else
      SUFFIX="redborder.cluster"
    fi

    sed -i "s|^bookshelf\['external_url'\] = \"https://s3\.service\"|bookshelf['external_url'] = \"https://s3.service.${SUFFIX}\"|" /etc/opscode/chef-server.rb
    systemctl restart opscode-erchef.service
    chef-server-ctl reconfigure
  ;;
esac

%postun
# Deletes directory when uninstall the package
if [ "$1" = 0 ] && [ -d /var/chef/cookbooks/minio ]; then
  rm -rf /var/chef/cookbooks/minio
fi

%files
%defattr(0755,root,root)
/var/chef/cookbooks/minio
%defattr(0644,root,root)
/var/chef/cookbooks/minio/README.md


%doc

%changelog
* Thu Oct 10 2024 Miguel Negrón <manegron@redborder.com>
- Add pre and postun

* Fri Jan 28 2022 David Vanhoucke <dvanhoucke@redborder.com>
- define attributes and update register to consul

* Fri Jan 07 2022 David Vanhoucke <dvanhoucke@redborder.com>
- change register to consul

* Wed Jan 24 2018 Alberto Rodriguez <arodriguez@redborder.com>
- first spec version
