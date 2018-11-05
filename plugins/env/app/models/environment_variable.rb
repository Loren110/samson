# frozen_string_literal: true
require 'validates_lengths_from_database'

class EnvironmentVariable < ActiveRecord::Base
  FAILED_LOOKUP_MARK = ' X' # SpaceX

  include GroupScope
  audited

  belongs_to :parent, polymorphic: true # Resource they are set on

  validates :name, presence: true

  include ValidatesLengthsFromDatabase
  validates_lengths_from_database only: :value

  class << self
    # preview parameter can be used to not raise an error,
    # but return a value with a helpful message
    # also used by an external plugin
    def env(project, deploy_group, preview: false, resolve_secrets: true)
      env_repo = ENV["DEPLOYMENT_ENV_REPO"]
      if env_repo
        env = get_env_vars_from_repo(env_repo,deploy_group, project)
      else
        env = get_env_vars_from_samson(deploy_group, project)
      end
      resolve_dollar_variables(env)
      resolve_secrets(project, deploy_group, env, preview: preview) if resolve_secrets
      env
    end

    # scopes is given as argument since it needs to be cached
    def sort_by_scopes(variables, scopes)
      variables.sort_by {|x| [x.name, scopes.index {|_, s| s == x.scope_type_and_id} || 999]}
    end

    def nested_variables(project)
      project.environment_variables + project.environment_variable_groups.flat_map(&:environment_variables)
    end

    # env_scopes is given as argument since it needs to be cached
    def serialize(variables, env_scopes)
      sorted = EnvironmentVariable.sort_by_scopes(variables, env_scopes)
      sorted.map do |var|
        "#{var.name}=#{var.value.inspect} # #{var.scope&.name || "All"}"
      end.join("\n")
    end

    private

    def get_env_vars_from_samson(deploy_group, project)
      variables = nested_variables(project)
      variables.sort_by!(&:priority)

      env = variables.each_with_object({}) do |ev, all|
        all[ev.name] = ev.value if !all[ev.name] && ev.matches_scope?(deploy_group)
      end
    end

    def get_env_vars_from_repo(env_repo,deploy_group, project)
      gh_contents = GITHUB.contents(env_repo, path: "generated/#{project}/#{deploy_group}.env", headers: {Accept: 'applications/vnd.github.v3.raw'})
      ghc_array = gh_contents.split(/\n+/)
      env = Hash[gh_array.collect {|line| k,v = line.split('=')}]
    end

    def resolve_dollar_variables(env)
      env.each do |k, value|
        env[k] = value.gsub(/\$\{(\w+)\}|\$(\w+)/) {|original| env[$1 || $2] || original}
      end
    end

    def resolve_secrets(project, deploy_group, env, preview:)
      resolver = Samson::Secrets::KeyResolver.new(project, Array(deploy_group))
      env.each do |key, value|
        next unless secret_key = value.dup.sub!(/^#{Regexp.escape TerminalExecutor::SECRET_PREFIX}/, '')
        found = resolver.read(secret_key)
        resolved =
            if preview
              path = resolver.expand_key(secret_key)
              path ? "#{TerminalExecutor::SECRET_PREFIX}#{path}" : "#{value}#{FAILED_LOOKUP_MARK}"
            else
              found.to_s
            end
        env[key] = resolved
      end
      resolver.verify! unless preview
    end
  end

  # used by `priority` from GroupScope
  def project?
    parent_type == "Project"
  end

  private

  def auditing_enabled
    parent_type != "Deploy" && super
  end
end
