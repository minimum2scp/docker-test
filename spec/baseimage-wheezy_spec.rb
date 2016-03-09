require 'spec_helper'

describe 'minimum2scp/baseimage-wheezy' do
  context 'with env [APT_LINE=keep]' do
    before(:all) do
      start_container({
        'Image' => ENV['DOCKER_IMAGE'] || "minimum2scp/baseimage-wheezy:ci",
        'Env' => [ 'APT_LINE=keep' ]
      })
    end

    after(:all) do
      stop_container
    end

    %w[
      sudo adduser curl ca-certificates openssl git lv vim-tiny man-db whiptail zsh net-tools unzip
      etckeeper locales tzdata localepurge sysvinit openssh-server rsyslog cron
    ].each do |pkg|
      describe package(pkg) do
        it { should be_installed }
      end
    end

    describe file("/etc/default/locale") do
      its(:content){ should include 'LANG=C' }
    end

    describe file("/etc/locale.gen") do
      its(:content){ should match /^en_US\.UTF-8\s+UTF-8\s*/ }
      its(:content){ should match /^ja_JP\.UTF-8\s+UTF-8\s*/ }
    end

    describe file("/etc/timezone") do
      its(:content){ should include 'Asia/Tokyo' }
    end

    describe file("/etc/localtime") do
      its(:md5sum){ should eq '9e165b3822e5923e4905ee1653a2f358' }
    end

    describe user('debian') do
      it { should be_exist }
      it { should belong_to_group 'debian' }
      it { should belong_to_group 'sudo' }
      it { should belong_to_group 'adm' }
      it { should have_uid 2000 }
      it { should have_home_directory '/home/debian' }
      it { should have_login_shell '/bin/bash' }
    end

    %w[ssh cron rsyslog].each do |svc|
      describe service(svc) do
        it { should be_enabled }
        it { should be_running }
      end
    end
  end
end
