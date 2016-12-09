require 'spec_helper'
require 'tmpdir'

describe WorkerScoreboard do
  describe '.new' do
    context 'For nested directory' do
      let(:base_dir) { File.join(Dir.tmpdir, 'level1', 'level2') }
      subject { WorkerScoreboard.new(base_dir) }
      example do
        expect { subject }.not_to raise_error
      end
    end
  end

  describe '#update' do
    let(:base_dir) { Dir.tmpdir }
    subject { WorkerScoreboard.new(base_dir) }
    it do
      subject.update('me manager')
      expect(subject.read_all.values.first).to eq 'me manager'
    end
  end
end
