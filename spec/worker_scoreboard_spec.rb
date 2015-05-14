require 'spec_helper'
require 'tmpdir'

describe WorkerScoreboard do
  context do
    let(:base_dir) { Dir.tmpdir }
    subject { WorkerScoreboard.new(base_dir) }
    it do
      subject.update('me manager')
      expect(subject.read_all.values.first).to eq 'me manager'
    end
  end
end
