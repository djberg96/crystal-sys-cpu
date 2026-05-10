require "./cpu/version"
require "./cpu/error"
require "./cpu/types"
require "./cpu/processor"

{% if flag?(:linux) %}
  require "./cpu/platform/linux"
{% elsif flag?(:darwin) %}
  require "./cpu/platform/darwin"
{% else %}
  require "./cpu/platform/unsupported"
{% end %}
