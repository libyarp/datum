# frozen_string_literal: true

RSpec.describe Datum::Migrator do
  after { Datum::Record.disconnect_all }

  it "fails to enumerate migrations in case path is not set" do
    expect { subject.enumerate_migrations }.to raise_error Datum::MigrationDirectoryNotSet
  end

  it "raises an error if migrations are not symmetrical" do
    allow(Datum).to receive(:migrations_path).and_return(File.join(__dir__, "..", "support", "migrations",
                                                                   "asymmetrical"))
    expect { subject.enumerate_migrations }.to raise_error Datum::AsymmetricalMigration
  end

  it "returns a coherent list of migrations" do
    allow(Datum).to receive(:migrations_path).and_return(File.join(__dir__, "..", "support", "migrations", "sqlite"))
    data = subject.enumerate_migrations
    expect(data.find { |v| v.id == "01" }).not_to be_nil
  end

  shared_examples_for "migrator" do
    before do
      allow(Datum).to receive(:migrations_path).and_return(File.join(__dir__, "..", "support", "migrations",
                                                                     adapter_name))
      Datum::Record.establish_connection(connection_url)
    end

    it "ensures a migration log table exists" do
      v = subject.migration_status
      expect(v.length).to eq 1
      expect(v.first).not_to be_up
    end

    it "shows unavailable migrations" do
      subject.migration_status

      Datum::Record.connection.register_migration(2)

      v = subject.migration_status
      expect(v.length).to eq 2
      expect(v.first).not_to be_up
      expect(v.last).to be_up
    end

    it "migrates forward" do
      subject.move_forward
    end

    it "migrates backward" do
      subject.move_forward
      subject.rollback
    end
  end

  context "with sqlite" do
    let(:adapter_name) { "sqlite" }
    let(:connection_url) { "sqlite://memory" }

    it_behaves_like "migrator"
  end

  context "with postgres" do
    let(:adapter_name) { "postgres" }
    let(:connection_url) { "postgres://postgres:postgres@localhost:5432/datum?sslmode=disable" }

    it_behaves_like "migrator" do
      after do
        Datum::Record.connection.execute("DROP TABLE IF EXISTS datum_metadata")
        Datum::Record.connection.execute("DROP TABLE IF EXISTS users")
      end
    end
  end

  context "with mysql" do
    let(:adapter_name) { "mysql" }
    let(:connection_url) { "mysql://root:mysql@127.0.0.1:3306/datum?sslmode=disable" }

    it_behaves_like "migrator" do
      after do
        Datum::Record.connection.execute("DROP TABLE IF EXISTS datum_metadata")
        Datum::Record.connection.execute("DROP TABLE IF EXISTS users")
      end
    end
  end
end
