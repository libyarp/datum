# frozen_string_literal: true

module Datum
  # Internal: Inflector transforms words to/from their singular and plural
  # representations.
  module Inflector
    module_function

    def pluralizer_rules
      @pluralizer_rules ||= {
        /(x|ch|ss)$/ => '\1es', # box, search, process
        /([^aeiouy]|qu)y$/ => '\1ies', # query, liability
        /(?:([^f])fe|([lr])f)$/ => '\1\2ves', # half, life
        /sis$/ => "ses", # basis, analisis
        /([ti])um$/ => '\1a', # datum, medium
        /person$/ => "people", # person, salesperson
        /man$/ => "men", # man, woman, spokesman
        /child$/ => "children",
        /s$/ => "s", # no change
        /$/ => "s" # anything else?
      }
    end

    def singularizer_rules
      @singularizer_rules ||= {
        /(x|ch|ss)es$/ => '\1',
        /([^aeiouy]|qu)ies$/ => '\1y',
        /([lr])ves$/ => '\1f',
        /([^f])ves$/ => '\1fe',
        /(analy|ba|diagno|parenthe|progno|synop|the)ses$/ => '\1sis',
        /([ti])a$/ => '\1um',
        /people$/ => "person",
        /men$/ => "man",
        /status$/ => "status",
        /children$/ => "child",
        /s$/ => ""
      }
    end

    def pluralize(str)
      str.dup.tap do |s|
        pluralizer_rules.each do |regexp, replace|
          break if s.gsub!(regexp, replace)
        end
      end
    end

    def singularize(str)
      str.dup.tap do |s|
        singularizer_rules.each do |regexp, replace|
          break if s.gsub!(regexp, replace)
        end
      end
    end

    def camelize(str)
      str.to_s.split("_").map(&:capitalize).join
    end

    def snakefy(str)
      str.gsub(/(.)([A-Z])/, '\1_\2').downcase
    end
  end
end

Inflector = Datum::Inflector
