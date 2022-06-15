# frozen_string_literal: true

RSpec.describe Datum::Adapter do
  it "indicates dependency errors" do
    conf = Datum::DSN.new(URI.parse("foo://test"))
    expect { described_class.connect(conf) }.to raise_error Datum::UnavailableAdapter
  end
end
