require "harassment/repositories/classification_job_repository"

describe Harassment::Repositories::ClassificationJobRepository do
  subject(:repository) { described_class.new }

  let(:job) { Harassment::ClassificationJob.build(server_id: 456, message_id: 123, classifier_version: "harassment-v1") }

  it "requires subclasses to implement #enqueue_unique" do
    expect { repository.enqueue_unique(job) }.to raise_error(NotImplementedError, /must implement #enqueue_unique/)
  end

  it "requires subclasses to implement #find" do
    expect do
      repository.find(server_id: "456", message_id: "123", classifier_version: "harassment-v1")
    end.to raise_error(NotImplementedError, /must implement #find/)
  end

  it "requires subclasses to implement #save" do
    expect { repository.save(job) }.to raise_error(NotImplementedError, /must implement #save/)
  end

  it "requires subclasses to implement #due_jobs" do
    expect { repository.due_jobs }.to raise_error(NotImplementedError, /must implement #due_jobs/)
  end
end
