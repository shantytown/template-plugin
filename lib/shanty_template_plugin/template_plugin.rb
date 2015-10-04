require 'deep_merge'
require 'erubis'
require 'fileutils'
require 'shanty/plugin'
require 'yaml'

module ShantyTemplatePlugin
  # Public: Shanty template plugin
  class TemplatePlugin < Shanty::Plugin
    PROJECT_EXTENSION = 'erb'
    DS_EXTENSTION = 'syaml'

    subscribe :build, :on_build
    provides_config :datasource, 'plain'
    provides_config :output_dir, 'build'
    provides_projects_containing "**/*.#{PROJECT_EXTENSION}"

    def on_build
      load_data.each do |template_env, data|
        project_files.each do |template|
          output = output_filename(template, template_env)
          FileUtils.mkdir_p(File.dirname(output))
          File.write(output, Erubis::Eruby.new(File.read(template)).result(data: data))
        end
      end
    end

    def artifacts
      load_data.keys.flat_map do |template_env|
        project_files.map do |template|
          filename = output_filename(template, template_env)
          Shanty::Artifact.new(File.extname(filename), self.class.name, URI("file://#{filename}"))
        end
      end
    end

    private

    def output_filename(template, env)
      file = File.basename(template, PROJECT_EXTENSION).split('.')

      File.join(project.path, config[:output_dir], filename(file, env))
    end

    def filename(file, env)
      if file.size > 1
        file_extension = "#{env}.#{file.last}"
        file.pop
        filename = file.join('.')
      else
        file_extension = env
        filename = file.first
      end

      "#{filename}.#{file_extension}"
    end

    def project_files
      @project_files ||= env.file_tree.glob("#{project.path}/*.#{PROJECT_EXTENSION}")
    end

    def load_data
      @data ||= artifact_paths.each_with_object({}) do |a, acc|
        data = YAML.load_file(a)
        validate!(a, data)
        acc.deep_merge!(data)
      end
    end

    def validate!(file, data)
      data.each do |_, v|
        fail "File #{file} is not valid for this plugin, each top level value must be a hash" unless v.is_a?(Hash)
      end
    end

    def all_artifacts
      project.parents.flat_map(&:all_artifacts).concat(project.all_artifacts)
    end

    def artifact_paths
      all_artifacts.keep_if do |a|
        a.local? && File.basename(a.uri.path) == "#{config[:datasource]}.#{DS_EXTENSTION}"
      end.map(&:to_local_path)
    end
  end
end
