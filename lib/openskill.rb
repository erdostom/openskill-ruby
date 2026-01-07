# frozen_string_literal: true

require_relative 'openskill/version'
require_relative 'openskill/statistics/normal'
require_relative 'openskill/models/common'
require_relative 'openskill/models/plackett_luce'
require_relative 'openskill/models/bradley_terry_full'
require_relative 'openskill/models/bradley_terry_part'
require_relative 'openskill/models/thurstone_mosteller_full'
require_relative 'openskill/models/thurstone_mosteller_part'

module OpenSkill
  class Error < StandardError; end
end
