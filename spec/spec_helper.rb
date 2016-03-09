require 'serverspec'
require 'net/ssh'
require 'docker'
require 'timeout'
require 'docker'
require 'logger'

set :logger, Logger.new($stderr).tap{|o| o.level = ENV['LOG_LEVEL']&.to_sym || :info }

## show debug log
Docker.logger = Specinfra.configuration.logger.dup
Docker.logger.level = (ENV['DOCKER_API_LOG_LEVEL']&.to_sym || :info)

## workaround for Circle CI
## docker rm (removing btrfs snapshot) fails on Circle CI
if ENV['CIRCLECI']
  class Docker::Container
    def remove(options={})
      # do not delete container
    end
    alias_method :delete, :remove
  end
end

set :backend, :ssh
set :ssh_options, {
  :user     => 'debian',
  :password => 'debian',
  :user_known_hosts_file => '/dev/null',
  :logger => Specinfra.configuration.logger.dup,
  :verbose => (ENV['NET_SSH_LOG_LEVEL']&.to_sym || :fatal),
}

set :os, :family => 'debian', :arch => 'x86_64', :release => nil

def start_container(opts)
  ## start container before run test
  container = ::Docker::Container.create(opts)
  container.start
  Specinfra.configuration.logger.info "Started container with opts=#{opts.inspect}:\n" + JSON.pretty_generate(container.json)

  ## save container object to Specinfra.configuration
  ## (to stop and delete container after suite)
  set :docker_container_obj, container

  ## configure ssh
  set :host, container.json['NetworkSettings']['IPAddress']

  ## wait for sshd in container start
  Timeout.timeout(60) do
    begin
      s = TCPSocket.open(container.json['NetworkSettings']['IPAddress'], 22)
      s.close
    rescue Errno::ECONNREFUSED
      sleep 1
      retry
    end
  end
end

def stop_container
  ## stop and delete container after test
  container = Specinfra.configuration.docker_container_obj
  container.delete(force: true)
  Specinfra.configuration.logger.info "Stopping container ..."

  ## reset Net::SSH object for next test
  Specinfra.backend.set_config(:ssh, nil)
end


