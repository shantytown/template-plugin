require 'shanty/project'

module ShantyTemplatePlugin
  # Test project
  class TestProject
    def initialize(dir, artifact)
      @dir = dir
      @artifact = artifact
    end

    def path
      @dir
    end

    def all_artifacts
      [Shanty::Artifact.new(File.extname(@artifact), 'test', URI("file://#{@artifact}"))]
    end

    def parents
      []
    end
  end
end
