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

%post
case "$1" in
  1)
    # This is an initial install.
    :
  ;;
  2)
    # This is an upgrade.
    su - -s /bin/bash -c 'source /etc/profile && rvm gemset use default && env knife cookbook upload minio'
  ;;
esac

%files
%defattr(0755,root,root)
/var/chef/cookbooks/minio
%defattr(0644,root,root)
/var/chef/cookbooks/minio/README.md


%doc

%changelog
* Fri Jan 07 2022 David Vanhoucke <dvanhoucke@redborder.com> - 0.0.2-1
- change register to consul
* Wed Jan 24 2018 Alberto Rodriguez <arodriguez@redborder.com> - 0.1.0-1
- first spec version
