# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end


Setting.put('trading_enabled', 'true')
Setting.put('risk.per_trade_rupees', '750')
Setting.put('risk.daily_loss_cap_rupees', '1500')
Setting.put('risk.max_trades_per_day', '4')
Setting.put('cooldown.seconds_after_exit', '120')