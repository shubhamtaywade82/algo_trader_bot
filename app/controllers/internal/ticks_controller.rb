# frozen_string_literal: true

module Internal
  class TicksController < ApplicationController
    def index
      render json: {
        ticks: Live::TickCache.all,
        stats: Live::TickCache.stats
      }
    end
  end
end
