class ScalpSession < ApplicationRecord
  enum :status, { idle: 'idle', running: 'running', stopped: 'stopped', killed: 'killed' }

  validates :trade_date, presence: true
  validates :capital, :max_day_loss, :realized_pnl, :equity_peak, numericality: true

  def equity
    capital + realized_pnl
  end
end
