require 'DhanHQ'

DhanHQ.configure_with_env
DhanHQ.logger.level = (ENV['DHAN_LOG_LEVEL'] || 'INFO').upcase.then { |l| Logger.const_get(l) }