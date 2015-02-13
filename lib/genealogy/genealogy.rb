module Genealogy

  extend ActiveSupport::Concern

  included do
    DEFAULTS = {
      column_names: {
        sex: 'sex',
        father_id: 'father_id',
        mother_id: 'mother_id',
        current_spouse_id: 'current_spouse_id',
        birth_date: 'birth_date',
        death_date: 'death_date',
      },
      perform_validation: true,
      current_spouse: false
    }
  end

  module ClassMethods
    
    def has_parents options = {}

      check_options(options)

      class_attribute :genealogy_enabled, :current_spouse_enabled, :genealogy_class, :perform_validation
      self.genealogy_enabled = true
      self.genealogy_class = self # keep track of the original extend class to prevent wrong scopes in query method in case of STI
      self.current_spouse_enabled = options[:current_spouse].try(:==,true) || false           # default false
      self.perform_validation = options[:perform_validation].try(:==,false) ? false : true    # default true

      # column names class attributes
      DEFAULTS[:column_names].merge(options[:column_names]).each do |k,v|
        class_attribute_name = "#{k}_column"
        class_attribute class_attribute_name
        self.send("#{class_attribute_name}=", v)
      end
      alias_attribute :sex, sex_column unless sex_column == 'sex'

      ## sex
      class_attribute :sex_values, :sex_male_value, :sex_female_value
      self.sex_values = options[:sex_values] || ['M','F']
      self.sex_male_value = self.sex_values.first
      self.sex_female_value = self.sex_values.last
      
      # validation
      validates_presence_of sex_column
      validates_format_of sex_column, :with => /[#{sex_values.join}]/

      tracked_relatives = [:father, :mother]
      tracked_relatives << :current_spouse if current_spouse_enabled
      tracked_relatives.each do |k|
        belongs_to k, class_name: self, foreign_key: self.send("#{k}_id_column")
      end

      has_many :children_as_father, :class_name => self, :foreign_key => self.father_id_column, :dependent => :nullify, :extend => FatherAssociationExtension
      has_many :children_as_mother, :class_name => self, :foreign_key => self.mother_id_column, :dependent => :nullify, :extend => MotherAssociationExtension

      # Include instance methods and class methods
      include Genealogy::UtilMethods
      include Genealogy::QueryMethods
      include Genealogy::IneligibleMethods
      include Genealogy::AlterMethods
      include Genealogy::SpouseMethods if current_spouse_enabled

    end

    module MotherAssociationExtension
      def with(father_id)
        where(father_id: father_id)
      end
    end
    module FatherAssociationExtension
      def with(mother_id)
        where(mother_id: mother_id)
      end
    end

    private

    def check_options(options)

      raise ArgumentError, "Hash expected, #{options.class} given." unless options.is_a? Hash

      # column names
      options[:column_names] ||= {}
      raise ArgumentError, "Hash expected for :column_names option, #{options[:column_names].class} given." unless options[:column_names].is_a? Hash

      # sex
      if array = options[:sex_values]
        raise ArgumentError, ":sex_values option must be an array of length 2: [:male_value, :female_value]" unless array.is_a?(Array) and array.size == 2
      end

      # booleans
      options.slice(:perform_validation, :current_spouse).each do |k,v|
        raise ArgumentError, "Boolean expected for #{k} option, #{v.class} given." unless !!v == v
      end
    end

  end

end