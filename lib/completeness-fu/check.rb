module CompletenessFu
  class Check < Struct.new(:name, :check, :weighting, :translation_namespace)
    attr_accessor :instance

    def pass?
      case self.check
      when Proc
        self.check.call(self.instance)
      when Symbol
        self.instance.send(self.check)
      else
        raise CompletenessFuError, "check of type #{self.check.class} not acceptable"
      end
    end

    def score(score_type)
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

    def title
      get_translation(:title)
    end

    def description
      get_translation(:description)
    end

    def extra
      get_translation(:extra)
    end

    private

    def get_translation(field)
      namespace = CompletenessFu.default_i18n_namespace + [self.translation_namespace, self.name]
      I18n.t(field.to_sym, :scope => namespace + [self.pass? ? :pass : :fail], :default => I18n.t(field.to_sym, :scope => namespace))
    end
  end
end