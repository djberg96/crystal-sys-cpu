module System
  module CPU
    private def blocking_sleep(seconds : Float64) : Nil
      span = seconds.seconds
      req = uninitialized LibC::Timespec
      req.tv_sec = typeof(req.tv_sec).new(span.total_seconds.to_i64)
      req.tv_nsec = typeof(req.tv_nsec).new(span.nanoseconds)

      loop do
        return if LibC.nanosleep(pointerof(req), out rem) == 0
        raise RuntimeError.from_errno("nanosleep() failed") unless Errno.value == Errno::EINTR
        req = rem
      end
    end
  end
end
