require "./cpu/version"
require "./cpu/error"
require "./cpu/types"
require "./cpu/processor"
require "./cpu/sampling"

{% if flag?(:linux) %}
  require "./cpu/platform/linux"
{% elsif flag?(:darwin) %}
  require "./cpu/platform/darwin"
{% elsif flag?(:freebsd) %}
  require "./cpu/platform/freebsd"
{% else %}
  require "./cpu/platform/unsupported"
{% end %}
