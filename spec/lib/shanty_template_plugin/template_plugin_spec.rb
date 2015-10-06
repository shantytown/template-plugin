require 'spec_helper'
require 'shanty/artifact'
require 'shanty_template_plugin/template_plugin'
require 'yaml'

RSpec.describe(ShantyTemplatePlugin::TemplatePlugin) do
  include_context('plugin')

  def test_output(data, expected_files, output_dir = 'build')
    setup_project(data)

    expect_artifacts(full_paths(expected_files, output_dir))
    expect_contents(full_paths(expected_files, output_dir))
  end

  def test_artifacts(data, expected_files, output_dir = 'build')
    setup_project(data)

    expect_artifacts(full_paths(expected_files, output_dir))
  end

  def setup_project(data)
    allow(project).to receive(:parents).and_return([parent])

    File.open(parent_artifact, 'wb') do |f|
      f.write(data.to_yaml)
    end

    subject.on_build
  end

  def expect_artifacts(expected_files)
    expect(subject.artifacts.map(&:to_local_path)).to match_array(expected_files.keys)
  end

  def expect_contents(expected_files)
    expected_files.each do |f, exp|
      expect(File.open(f, 'rb').read.strip).to eql(exp)
    end
  end

  def full_paths(expected_files, output_dir)
    expected_files.each_with_object({}) do |v, acc|
      acc[File.join(root, 'one', output_dir, v.first)] = v.last
    end
  end

  before(:each) do
    File.write(File.join(project_path, 'test.erb'), '<%= data[\'nic\'] %>')
    FileUtils.mkdir_p(File.dirname(parent_artifact))
    allow(project).to receive(:path).and_return(project_path)
    allow(project).to receive(:parents).and_return([])
    allow(project).to receive(:config).and_return({})
    allow(project).to receive(:all_artifacts).and_return([])
    allow(file_tree).to receive(:glob).and_return(
      [File.join(project_path, 'test.erb')]
    )
    allow(parent_project).to receive(:path).and_return(parent_dir)
    allow(parent_project).to receive(:all_artifacts).and_return(
      [Shanty::Artifact.new(File.extname(parent_artifact), 'test', URI("file://#{parent_artifact}"))]
    )
    allow(parent_project).to receive(:parents).and_return([])
  end

  let(:parent_dir) { File.join(root, 'two') }
  let(:parent_artifact) { File.join(parent_dir, 'build', 'plain.syaml') }
  let(:parent) { parent_project }
  let(:parent_project) { double('parent_project') }

  it('adds the template tag automatically') do
    expect(described_class.tags).to match_array([:template])
  end

  it('adds option for the output dir') do
    expect(described_class).to add_config(:output_dir, 'build')
  end

  it('adds option for the datasource name') do
    expect(described_class).to add_config(:datasource, 'plain')
  end

  it('finds projects that have erb files') do
    expect(described_class).to provide_projects_containing('**/*.erb')
  end

  it('subscribes to the build event') do
    expect(described_class).to subscribe_to(:build).with(:on_build)
  end

  describe('#on_build') do
    it('does not create any artifacts when no parents exist') do
      expect(subject.artifacts).to be_empty
    end

    it('populates a template when using a single environment') do
      test_output({ 'test1' => { 'nic' => 'cage' } }, 'test.test1' => 'cage')
    end

    it('can cope with templates with file extensions') do
      FileUtils.rm_f(File.join(root, 'one', 'test.erb'))
      File.write(File.join(root, 'one', 'test.txt.erb'), '<%= data[\'nic\'] %>')
      allow(file_tree).to receive(:glob).and_return(
        [File.join(project_path, 'test.txt.erb')]
      )

      test_output({ 'test1' => { 'nic' => 'cage' } }, 'test.test1.txt' => 'cage')
    end

    it('can cope with multiple environments') do
      test_output({ 'test1' => { 'nic' => 'cage' }, 'test2' => { 'nic' => 'copolla' } },
                  'test.test1' => 'cage', 'test.test2' => 'copolla')
    end
  end

  describe('#artifacts') do
    it('fails to load data when input is not a hash') do
      allow(project).to receive(:parents).and_return([parent])

      File.open(parent_artifact, 'wb') do |f|
        f.write({ 'test1' => 'derp' }.to_yaml)
      end

      expect do
        subject.artifacts
      end.to raise_error("File #{parent_artifact} is not valid for this plugin, each top level value must be a hash")
    end

    it('write artifacts to a different output directory') do
      allow(env).to receive(:config).and_return(template: { output_dir: 'nic_cage' })

      test_artifacts({ 'test1' => { 'nic' => 'cage' } }, { 'test.test1' => 'cage' }, 'nic_cage')
    end
  end

  describe('#artifacts') do
    let(:parent_artifact) { File.join(parent_dir, 'build', 'encrypted.syaml') }

    it('can read data from a different data source') do
      allow(env).to receive(:config).and_return(template: { datasource: 'encrypted' })

      test_artifacts({ 'test1' => { 'nic' => 'cage' } }, 'test.test1' => 'cage')
    end
  end
end
