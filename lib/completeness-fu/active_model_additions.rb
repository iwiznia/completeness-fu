if Gem.loaded_specs['activesupport'].version > Gem::Version.create('3.2.0.pre')
  require 'active_support/core_ext/class/attribute'
else
  require 'active_support/core_ext/class/inheritable_attributes'
end
require 'active_support/core_ext/class/attribute_accessors'

module CompletenessFu
  module ActiveModelAdditions
    def self.included(base)
      base.class_eval do
        def self.define_completeness_scoring(&checks_block)
          unless self.respond_to?(:model_name)
            raise CompletenessFuError, 'please make sure ActiveModel::Naming is included so completeness_scoring can translate messages correctly, or that you implement a model_name method.'
          end

          #class_attribute :completeness_checks
          class << self
            attr_accessor :completeness_checks
          end
          cattr_accessor :default_weighting
          cattr_accessor :model_weightings

          self.send :extend,  ClassMethods
          self.send :include, InstanceMethods

          checks_results = CompletenessFu::ScoringBuilder.generate(self, &checks_block)

          self.default_weighting   = checks_results[:default_weighting]
          self.completeness_checks = checks_results[:completeness_checks]
          self.model_weightings    = checks_results[:model_weightings]

          if checks_results[:cache_score_details]
            unless self.include?(ActiveModel::Validations::Callbacks)
              raise CompletenessFuError, 'please make sure ActiveModel::Validations::Callbacks is included before define_completeness_scoring if you want to cache competeness scoring'
            end
            self.before_validation checks_results[:cache_score_details]
          end
        end
      end
    end

    module ClassMethods
      def max_completeness_score
        self.completeness_checks.sum(&:weighting)
      end
    end

    module InstanceMethods
      def completeness_checks
        @completeness_checks ||= self.class.completeness_checks.deep_dup.each {|c| c.instance = self }
      end

      # returns an array of hashes with the translated name, description + weighting
      def failed_checks
        all_checks_which_pass(false)
      end

      # returns an array of hashes with the translated name, description + weighting
      def passed_checks
        all_checks_which_pass
      end

      # returns the absolute complete score
      def completeness_score
        passed_checks.sum(&:weighting)
      end

      # returns the percentage of completeness (relative score)
      def percent_complete
        self.completeness_score.to_f / self.class.max_completeness_score.to_f  * 100
      end

      # returns a basic 'grading' based on percent_complete, defaults are :high, :medium, :low, and :poor
      def completeness_grade
        CompletenessFu.default_gradings.each do |grading|
          return grading.first if grading.last.include?(self.percent_complete.round)
        end
        raise CompletenessFuError, "grade could not be determined with percent complete #{self.percent_complete.round}"
      end

      private

        def all_checks_which_pass(should_pass = true)
          self.completeness_checks.select do |check|
            check_result = check.pass?
            should_pass ? check_result : !check_result
          end
        end

        def cache_completeness_score(score_type)
          score = case score_type
                  when :relative
                    self.percent_complete
                  when :absolute
                    self.completeness_score
                  else
                    raise ArgumentException, 'completeness scoring type not recognized'
                  end
          self.cached_completeness_score = score.round
          true
        end
    end
  end
end