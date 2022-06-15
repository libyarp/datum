# frozen_string_literal: true

RSpec.describe Datum::Queries do
  require_relative "../support/user"

  shared_examples_for "adapter" do
    before do
      Datum::Record.disconnect_all
      Datum::Record.establish_connection(connection_url)
      allow(Datum).to receive(:migrations_path).and_return(File.join(__dir__, "..", "support", "migrations",
                                                                     adapter_name))
      Datum::Migrator.new.move_forward
      User.remove_instance_variable :@columns if User.instance_variable_defined? :@columns
      User.columns
    end

    let(:time) { Time.local(2008, 10, 27, 18, 43, 0).utc }
    let(:users) do
      {
        paul: { email: "paul@example.org", name: "Paul Appleseed" },
        nick: { email: "nick@example.org", name: "Nick Appleseed" },
        alice: { email: "alice@example.org", name: "Alice Appleseed" }
      }
    end

    def create_user(who)
      Timecop.freeze(time) do
        u = User.new(**users[who].merge(active: true))
        u.save
        u
      end
    end

    def assert_user(who, u)
      expect(u.created_at).to eq time
      expect(u.updated_at).to eq time
      expect(u).to be_persisted
      expect(u.changed_fields).to be_empty
      expect(u.changed_fields).to be_empty
      expect(u.email).to eq users[who][:email]
      expect(u.name).to eq users[who][:name]
      expect(u.active).to be true
    end

    it "inserts a new item" do
      u = create_user(:paul)
      expect(u.id).to eq 1
      expect(u.created_at).to eq time
      expect(u.updated_at).to eq time
      expect(u).to be_persisted
      expect(u.changed_fields).to be_empty
      expect(u.changed_fields).to be_empty
    end

    describe "#find" do
      it "finds a single item" do
        create_user(:paul)
        u = User.find(1)
        expect(u.id).to eq 1
        assert_user(:paul, u)
      end

      it "returns nil when a record is not found" do
        u = User.find 10
        expect(u).to be_nil
      end
    end

    describe "#find!" do
      it "finds a single item" do
        create_user(:paul)
        u = User.find! 1
        expect(u.id).to eq 1
        assert_user(:paul, u)
      end

      it "raises RecordNotFound" do
        expect { User.find! 2 }.to raise_error(Datum::RecordNotFound)
      end
    end

    describe "#find_by" do
      it "finds by a condition" do
        create_user(:paul)
        u = User.find_by email: users[:paul][:email]
        expect(u.id).to eq 1
        assert_user(:paul, u)
      end

      it "returns nil when a record is not found" do
        u = User.find_by email: "nope"
        expect(u).to be_nil
      end
    end

    describe "#find_by!" do
      it "finds by a condition" do
        create_user(:paul)
        u = User.find_by! email: users[:paul][:email]
        expect(u.id).to eq 1
        assert_user(:paul, u)
      end

      it "raises RecordNotFound" do
        expect { User.find_by! email: "nope" }.to raise_error(Datum::RecordNotFound)
      end
    end

    describe "#first" do
      it "returns the first item" do
        create_user(:paul)
        create_user(:nick)

        u = User.first
        assert_user(:paul, u)
      end

      it "returns nil in case no item exist" do
        u = User.first
        expect(u).to be_nil
      end

      it "returns the first two items" do
        create_user(:paul)
        create_user(:nick)
        create_user(:alice)

        us = User.first(2)
        expect(us.length).to eq 2
        assert_user(:paul, us.first)
        assert_user(:nick, us.last)
      end
    end

    describe "#first!" do
      it "returns the first item" do
        create_user(:paul)
        create_user(:nick)

        u = User.first!
        assert_user(:paul, u)
      end

      it "raises RecordNotFound in case no items exist" do
        expect { User.first! }.to raise_error(Datum::RecordNotFound)
      end
    end

    describe "#last" do
      it "returns the last item" do
        create_user(:paul)
        create_user(:nick)

        u = User.last
        assert_user(:nick, u)
      end

      it "returns nil in case no item exist" do
        u = User.last
        expect(u).to be_nil
      end

      it "returns the last two items" do
        create_user(:paul)
        create_user(:nick)
        create_user(:alice)

        us = User.last(2)
        expect(us.length).to eq 2
        assert_user(:alice, us.first)
        assert_user(:nick, us.last)
      end
    end

    describe "#last!" do
      it "returns the last item" do
        create_user(:paul)
        create_user(:nick)

        u = User.last!
        assert_user(:nick, u)
      end

      it "raises RecordNotFound in case no items exist" do
        expect { User.last! }.to raise_error(Datum::RecordNotFound)
      end
    end

    describe "#find_by_sql" do
      it "returns an item by sql" do
        create_user(:paul)
        create_user(:nick)

        u = User.find_by_sql("email = #{first_item_placeholder}", users[:nick][:email])
        assert_user(:nick, u)
      end

      it "returns nil when no results match" do
        u = User.find_by_sql("email = #{first_item_placeholder}", "no")
        expect(u).to be_nil
      end

      it "rejects keyword arguments" do
        expect { User.find_by_sql("email = #{first_item_placeholder}", key: :value) }.to raise_error(ArgumentError)
      end
    end

    describe "#find_by_sql!" do
      it "returns an item by sql" do
        create_user(:paul)
        create_user(:nick)

        u = User.find_by_sql!("email = #{first_item_placeholder}", users[:nick][:email])
        assert_user(:nick, u)
      end

      it "raises RecordNotFound in case no items exist" do
        expect { User.find_by_sql! "email = #{first_item_placeholder}", "no" }.to raise_error(Datum::RecordNotFound)
      end
    end

    describe "#where" do
      it "finds items by condition" do
        create_user(:paul)
        items = User.where(active: true)
        expect(items.length).to eq 1
      end

      it "finds items by sql" do
        create_user(:paul)
        items = User.where("id > #{first_item_placeholder}", 0)
        expect(items.length).to eq 1
      end

      it "forbids usage of args and kwargs" do
        expect { User.where("foo", bar: true) }.to raise_error(ArgumentError)
      end
    end

    describe "#count" do
      it "counts items" do
        create_user(:paul)
        expect(User.count).to eq 1
        create_user(:nick)
        expect(User.count).to eq 2
      end
    end

    describe "#limit" do
      it "limits results" do
        create_user(:paul)
        create_user(:nick)
        create_user(:alice)
        users = User.limit(2)
        expect(users.length).to eq 2
      end

      it "forbids extraneous values" do
        create_user(:paul)
        create_user(:nick)
        create_user(:alice)
        expect { User.limit(:foo) }.to raise_error ArgumentError
      end
    end

    describe "#skip" do
      it "skips results" do
        create_user(:paul)
        create_user(:nick)
        create_user(:alice)
        users = User.skip(1).limit(2).to_a
        expect(users.length).to eq 2
        expect(users.first.id).to eq 2
        expect(users.last.id).to eq 3
      end

      it "forbids extraneous values" do
        expect { User.skip(:foo) }.to raise_error ArgumentError
      end
    end

    describe "#in_batches_of" do
      it "loads results" do
        create_user(:paul)
        create_user(:nick)
        create_user(:alice)
        expect(User.connection).to receive(:select).once.and_call_original
        users = User.in_batches_of(2).limit(2).to_enum.to_a
        expect(users.length).to eq 2
      end
    end

    describe "#each" do
      it "loads results" do
        create_user(:paul)
        User.each do |u|
          expect(u.id).to eq 1
        end
      end
    end

    describe "#map" do
      it "loads results" do
        create_user(:paul)
        expect(User.map(&:id)).to eq [1]
      end
    end

    describe "#delete" do
      it "deletes users" do
        create_user(:paul)
        expect(User.count).to eq 1
        User.where(id: 1).delete
        expect(User.count).to eq 0
      end
    end

    describe "#update" do
      it "updates user" do
        create_user(:paul)
        expect(User.count).to eq 1
        User.where(id: 1).update(name: "Alice")
        expect(User.first.name).to eq "Alice"
      end
    end

    context "model update" do
      it "updates user" do
        create_user(:paul)
        u = User.first
        u.update(name: "Alice")
        expect(User.first.name).to eq "Alice"
      end
    end

    context "model delete" do
      it "deletes user" do
        create_user(:paul)
        u = User.first
        u.delete
        expect(User.count).to eq 0
      end
    end

    context "transaction" do
      it "updates user" do
        create_user(:paul)
        u = User.first
        User.transaction do
          u.update(name: "Alice")
        end
        expect(User.first.name).to eq "Alice"
      end

      it "rolls-back upon errors" do
        create_user(:paul)
        u = User.first
        expect do
          User.transaction do
            u.update(name: "Alice")
            raise ArgumentError
          end
        end.to raise_error ArgumentError
        expect(User.first.name).to eq "Paul Appleseed"
      end
    end
  end

  context "with sqlite" do
    let(:adapter_name) { "sqlite" }
    let(:connection_url) { "sqlite://memory" }
    let(:first_item_placeholder) { "?" }

    it_behaves_like "adapter"
  end

  context "with postgres" do
    let(:adapter_name) { "postgres" }
    let(:connection_url) { "postgres://postgres:postgres@localhost:5432/datum?sslmode=disable" }
    let(:first_item_placeholder) { "$1" }

    it_behaves_like "adapter" do
      after do
        Datum::Record.connection.execute("DROP TABLE IF EXISTS datum_metadata")
        Datum::Record.connection.execute("DROP TABLE IF EXISTS users")
      end
    end
  end

  context "with mysql" do
    let(:adapter_name) { "mysql" }
    let(:connection_url) { "mysql://root:mysql@127.0.0.1:3306/datum?sslmode=disable" }
    let(:first_item_placeholder) { "?" }

    it_behaves_like "adapter" do
      after do
        Datum::Record.connection.execute("DROP TABLE IF EXISTS datum_metadata")
        Datum::Record.connection.execute("DROP TABLE IF EXISTS users")
      end
    end
  end
end
