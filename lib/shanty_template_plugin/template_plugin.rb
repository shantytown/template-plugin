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

    option :datasource, 'plain'
    option :output_dir, 'build'
    subscribe :build, :on_build
    projects "**/*.#{PROJECT_EXTENSION}"

    def on_build(project)
      load_data(project).each do |env, data|
        project_files(project).each do |template|
          output = output_filename(project, template, env)
          FileUtils.mkdir_p(File.dirname(output))
          File.write(output, Erubis::Eruby.new(File.read(template)).result(data: data))
        end
      end
    end

    def artifacts(project)
      load_data(project).keys.flat_map do |env|
        project_files(project).map do |template|
          filename = output_filename(project, template, env)
          Shanty::Artifact.new(File.extname(filename), self.class.name, URI("file://#{filename}"))
        end
      end
    end

    private

    def output_filename(project, template, env)
      file = File.basename(template, PROJECT_EXTENSION).split('.')

      File.join(project.path, self.class.options.output_dir, filename(file, env))
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

    def project_files(project)
      @project_files ||= project_tree.glob("#{project.path}/*.#{PROJECT_EXTENSION}")
    end

    def load_data(project)
      @data ||= artifact_paths(project).each_with_object({}) do |a, acc|
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

    def artifact_paths(project)
      (project.parents.flat_map(&:all_artifacts).concat(project.all_artifacts)).keep_if do |a|
        a.local? && File.basename(a.uri.path) == "#{self.class.options.datasource}.#{DS_EXTENSTION}"
      end.map(&:to_local_path)
    end
  end
end
