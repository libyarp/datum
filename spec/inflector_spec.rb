# frozen_string_literal: true

RSpec.describe Inflector do
  subject { described_class }

  cases = {
    "box" => "boxes",
    "search" => "searches",
    "process" => "processes",
    "half" => "halves",
    "life" => "lives",
    "basis" => "bases",
    "analysis" => "analyses",
    "datum" => "data",
    "medium" => "media",
    "person" => "people",
    "salesperson" => "salespeople",
    "child" => "children",
    "birb" => "birbs"
  }

  cases.each do |singular, plural|
    it "pluralizes #{singular} => #{plural}" do
      expect(subject.pluralize(singular)).to eq plural
    end

    it "singularizes #{plural} => #{singular}" do
      expect(subject.singularize(plural)).to eq singular
    end
  end
end
