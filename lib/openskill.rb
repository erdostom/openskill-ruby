# frozen_string_literal: true

require_relative 'openskill/version'
require_relative 'openskill/statistics/normal'
require_relative 'openskill/models/common'
require_relative 'openskill/models/plackett_luce'

module OpenSkill
  class Error < StandardError; end
end
