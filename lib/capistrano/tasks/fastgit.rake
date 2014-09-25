namespace :fastgit do

  set :git_environmental_variables, ->() {
    {
        git_askpass: "/bin/echo",
        git_ssh:     "#{fetch(:tmp_dir)}/#{fetch(:application)}/git-ssh.sh"
    }
  }

  desc 'Upload the git wrapper script, this script guarantees that we can script git without getting an interactive prompt'
  task :wrapper do
    on roles :all do
      execute :mkdir, "-p", "#{fetch(:tmp_dir)}/#{fetch(:application)}/"
      upload! StringIO.new("#!/bin/sh -e\nexec /usr/bin/ssh -o PasswordAuthentication=no -o StrictHostKeyChecking=no \"$@\"\n"), "#{fetch(:tmp_dir)}/#{fetch(:application)}/git-ssh.sh"
      execute :chmod, "+x", "#{fetch(:tmp_dir)}/#{fetch(:application)}/git-ssh.sh"
    end
  end

  desc 'Check that the repository is reachable'
  task check: :'fastgit:wrapper' do
    fetch(:branch)
    on roles :all do
      with fetch(:git_environmental_variables) do
        exit 1 unless test :git, :'ls-remote', repo_url
      end
    end
  end

  desc 'Clone the repo to the cache'
  task clone: :'fastgit:wrapper' do
    on roles :all do
      if test " [ -d #{deploy_path}/.git ] "
        info t(:mirror_exists, at: deploy_path)
      else
        with fetch(:git_environmental_variables) do
          execute :git, :clone, repo_url, deploy_path
        end
      end
    end
  end

  desc 'Update the repo mirror to reflect the origin state'
  task update: :'fastgit:clone' do
    on roles :all do
      within deploy_path do
        execute :git, :fetch
        execute :git, :reset, '--hard', "origin/#{fetch(:branch)}"
      end
    end
  end

  desc 'Copy repo to releases'
  task create_release: :'fastgit:update' do
    # nada
  end
end

namespace :deploy do
  task(:check).clear.enhance(['fastgit:check'])
  task(:publishing).clear.enhance(['deploy:restart'])
  task(:updating).clear.enhance(['fastgit:create_release'])
  task(:cleanup).clear
  task(:log_revision).clear
end
