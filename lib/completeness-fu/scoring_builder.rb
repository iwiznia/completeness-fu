module CompletenessFu

  # A simple clean room for setting up the completeness check information
  class ScoringBuilder

    attr_accessor :completeness_checks, :model_weightings, :cache_score_details, :default_weighting, :model_class

    def self.generate(model_class, &block)
      sb = ScoringBuilder.new()

      sb.model_class = model_class
      sb.completeness_checks = []
      sb.default_weighting   = CompletenessFu.default_weighting
      sb.model_weightings    = CompletenessFu.common_weightings

      sb.instance_eval(&block)

      { :completeness_checks => sb.completeness_checks,
        :model_weightings    => sb.model_weightings,
        :cache_score_details => sb.cache_score_details,
        :default_weighting   => sb.default_weighting }
    end


    private

      def check(name, check, weighting = nil)
        weighting ||= self.default_weighting
        weighting = self.model_weightings[weighting] if weighting.is_a?(Symbol)
        self.completeness_checks << CompletenessFu::Check.new(name, check, weighting, self.model_class.model_name.name.underscore.to_sym)
      end

      def weightings(custom_weighting_opts)
        use_common = custom_weighting_opts.delete(:merge_with_common)
        if use_common
          self.model_weightings.merge!(custom_weights)
        else
          self.model_weightings = custom_weighting_opts
        end
      end

      def cache_score(score_type = :relative)
        self.cache_score_details = lambda { |instance| instance.send :cache_completeness_score, score_type }
      end
  end
end