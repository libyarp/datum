# frozen_string_literal: true

RSpec.describe Datum::Record do
  before { Datum::Record.disconnect_all }
  after { Datum::Record.disconnect_all }

  it "returns whether connection has been established" do
    expect(Datum::Record.connection_established?).to eq false
    Datum::Record.establish_connection("sqlite://foo")
    expect(Datum::Record.connection_established?).to eq true
  end
end
