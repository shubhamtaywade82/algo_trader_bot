module PgLocks
  def self.with_lock(key)
    lock_id = Zlib.crc32(key.to_s)
    ActiveRecord::Base.connection.execute("SELECT pg_advisory_lock(#{lock_id})")
    yield
  ensure
    ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock(#{lock_id})")
  end
end